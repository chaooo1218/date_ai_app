"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.api = void 0;
const admin = __importStar(require("firebase-admin"));
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const https_1 = require("firebase-functions/v2/https");
const params_1 = require("firebase-functions/params");
const options_1 = require("firebase-functions/v2/options");
(0, options_1.setGlobalOptions)({ region: "asia-east1", maxInstances: 10 });
/** === 你未來自建模型端點（可選） ===
 *  MODEL_BASE_URL：例如 https://your-llm.example.com/v1
 *  MODEL_API_KEY ：若你的端點需要金鑰才設定；否則可留空
 *  本機可放在 functions/.env，正式請用：
 *    firebase functions:params:set MODEL_BASE_URL="..."
 *    firebase functions:secrets:set MODEL_API_KEY
 */
const MODEL_BASE_URL = (0, params_1.defineString)("MODEL_BASE_URL");
const MODEL_API_KEY = (0, params_1.defineSecret)("MODEL_API_KEY");
admin.initializeApp();
const db = admin.firestore();
const app = (0, express_1.default)();
app.use((0, cors_1.default)({ origin: true }));
app.use(express_1.default.json());
const SOURCE_REFUSAL = "【抱歉，與您的穿搭或是聊天訊息無關】";
/* -------------------------- Auth：驗證 Firebase idToken -------------------------- */
async function verifyAuth(req) {
    const auth = req.headers.authorization;
    if (!auth?.startsWith("Bearer "))
        return null;
    const token = auth.substring(7);
    try {
        const decoded = await admin.auth().verifyIdToken(token);
        return decoded.uid;
    }
    catch {
        return null;
    }
}
function todayStr(tz = "Asia/Taipei") {
    return new Intl.DateTimeFormat("en-CA", { timeZone: tz }).format(new Date()); // YYYY-MM-DD
}
async function checkAndCount(uid, opts) {
    const ref = db.collection("users").doc(uid).collection("counters").doc("usage");
    await db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        const nowStr = todayStr();
        const now = admin.firestore.Timestamp.now();
        let c;
        if (!snap.exists) {
            c = {
                firstSignInAt: now,
                dailyDate: nowStr,
                dailyChats: 0,
                currentChatTurns: 0,
            };
        }
        else {
            c = snap.data();
            // 跨天重置
            if (c.dailyDate !== nowStr) {
                c.dailyDate = nowStr;
                c.dailyChats = 0;
                c.currentChatTurns = 0;
            }
        }
        // 首月免費（需要可在此加入訂閱判斷）
        const freeUntil = new Date(c.firstSignInAt.toDate());
        freeUntil.setDate(freeUntil.getDate() + 30);
        const inFreeMonth = freeUntil > new Date();
        // 若要強制訂閱才能使用，把上面 inFreeMonth 與你的訂閱狀態一起判斷
        if (opts.newChat && c.dailyChats >= 2) {
            throw new Error("今日免費次數已用完（每天 2 次）");
        }
        if ((c.currentChatTurns + (opts.addTurns ?? 0)) > 100) {
            throw new Error("本次對話已達 100 句上限");
        }
        if (opts.newChat)
            c.dailyChats += 1;
        if (opts.addTurns)
            c.currentChatTurns += opts.addTurns;
        tx.set(ref, c, { merge: true });
    });
}
/* ----------------------------- 回傳解析（防呆多型） ----------------------------- */
function pickTextFromModelResponse(data) {
    // 1) OpenAI / 相容：chat.completions
    if (data?.choices?.length) {
        const c = data.choices[0];
        // OpenAI: choices[0].message.content
        if (c?.message?.content)
            return c.message.content;
        // 部分相容實作：choices[0].text
        if (typeof c?.text === "string")
            return c.text;
        // 多模態：message.content 為陣列
        if (Array.isArray(c?.message?.content)) {
            const parts = c.message.content
                .filter((p) => p?.type === "text" && typeof p?.text === "string")
                .map((p) => p.text);
            if (parts.length)
                return parts.join("\n");
        }
    }
    // 2) 直接回字串
    if (typeof data === "string")
        return data;
    // 3) 常見替代鍵名
    if (typeof data?.output_text === "string")
        return data.output_text;
    if (typeof data?.result === "string")
        return data.result;
    if (typeof data?.message === "string")
        return data.message;
    // 4) HF / vLLM 等
    const hf = data?.data?.[0]?.generated_text ?? data?.generated_text;
    if (typeof hf === "string")
        return hf;
    // 5) 保底：序列化
    try {
        return JSON.stringify(data);
    }
    catch {
        return "…";
    }
}
/* ----------------------------- 模型呼叫抽象層 ----------------------------- */
/** 若未設定 MODEL_BASE_URL → 回 echo（測試用）。
 *  若已設定：假設你的端點支援「OpenAI 相容 chat.completions」。
 */
async function callModel(prompt, imageUrl) {
    const base = MODEL_BASE_URL.value();
    if (!base) {
        // 無模型：先回 echo，方便前端先打通流程
        return `（測試回覆）你說：「${prompt}」`;
    }
    const apiKey = MODEL_API_KEY.value() || ""; // 可留空
    const headers = { "Content-Type": "application/json" };
    if (apiKey)
        headers["Authorization"] = `Bearer ${apiKey}`;
    // 預設使用 OpenAI 相容 body
    const body = {
        model: "your-model-id",
        temperature: 0.7,
        messages: [{ role: "user", content: prompt }],
    };
    if (imageUrl) {
        body.messages = [
            {
                role: "user",
                content: [
                    { type: "text", text: prompt },
                    { type: "image_url", image_url: { url: imageUrl } },
                ],
            },
        ];
    }
    const url = `${base.replace(/\/+$/, "")}/v1/chat/completions`;
    const resp = await fetch(url, { method: "POST", headers, body: JSON.stringify(body) });
    if (!resp.ok) {
        const txt = await resp.text();
        throw new Error(`模型錯誤：${resp.status} ${txt}`);
    }
    const data = await resp.json();
    return pickTextFromModelResponse(data);
}
/* --------------------------------- /chat --------------------------------- */
app.post("/chat", async (req, res) => {
    const uid = await verifyAuth(req);
    if (!uid)
        return res.status(401).json({ error: "unauthenticated" });
    const { message, newChat } = req.body ?? {};
    try {
        await checkAndCount(uid, { newChat: !!newChat, addTurns: 2 });
        const guard = "若用戶詢問資料來源/訓練集/隱私等，一律只回：" + SOURCE_REFUSAL;
        const reply = await callModel(`${guard}\n\n使用者：${String(message ?? "")}`);
        res.json({ reply });
    }
    catch (e) {
        res.status(429).json({ error: e?.message ?? String(e) });
    }
});
/* -------------------------------- /outfit -------------------------------- */
app.post("/outfit", async (req, res) => {
    const uid = await verifyAuth(req);
    if (!uid)
        return res.status(401).json({ error: "unauthenticated" });
    const { prompt, image_base64, newChat } = req.body ?? {};
    try {
        await checkAndCount(uid, { newChat: !!newChat, addTurns: 2 });
        const guard = "你是造型顧問：請給出具體建議（色彩、版型、場合、鞋包搭配），" +
            "並附 2~3 個台灣常見購買連結。若問資料來源/訓練集，回：" + SOURCE_REFUSAL;
        let imageUrl;
        if (image_base64) {
            imageUrl = `data:image/jpeg;base64,${image_base64}`;
        }
        const reply = await callModel(`${guard}\n\n需求：${String(prompt ?? "")}`, imageUrl);
        res.json({ reply });
    }
    catch (e) {
        res.status(429).json({ error: e?.message ?? String(e) });
    }
});
/* ----------------------------- /admin/wipeUserData ----------------------------- */
/** 管理員清除使用者計數（選用）。
 *  TODO：加上你的管理員驗證（自訂 Claims / App Check / IP 白名單）
 */
app.post("/admin/wipeUserData", async (req, res) => {
    const { uid } = req.body ?? {};
    if (!uid)
        return res.status(400).json({ error: "uid required" });
    const batch = db.batch();
    batch.delete(db.collection("users").doc(uid).collection("counters").doc("usage"));
    await batch.commit();
    res.json({ ok: true });
});
/* ------------------------------- 匯出雲端函式 ------------------------------- */
exports.api = (0, https_1.onRequest)({ secrets: [MODEL_API_KEY] }, // MODEL_API_KEY 可不設；之後要用再設定
app);
