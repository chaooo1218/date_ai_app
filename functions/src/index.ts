import * as admin from "firebase-admin";                    // 匯入 Firebase Admin SDK（後端用：Firestore、Auth 等）
import express, { Request, Response } from "express";        // 匯入 Express（HTTP 伺服器），順便拿到型別 Request/Response 做自動提示
import cors from "cors";                                     // 匯入 CORS 中介層，允許跨網域請求（給你的 App 打 API 用）;這部分挺重要，可以再查一下資料

import { onRequest } from "firebase-functions/v2/https";     // v2 版的 https 觸發（把 Express app 包成雲端函式）
import { defineSecret, defineString } from "firebase-functions/params"; // 讀取雲端環境變數/Secrets（正式環境）
import { setGlobalOptions } from "firebase-functions/v2/options";       // 設定這個檔案裡所有函式的全域選項

setGlobalOptions({ region: "asia-east1", maxInstances: 10 }); // 設定所有函式跑在 asia-east1，最多同時 10 個執行個體

/** === 未來自建模型端點 ===
 *  MODEL_BASE_URL：例如 https://your-llm.example.com/v1
 *  MODEL_API_KEY ：若你的端點需要金鑰才設定；否則可留空
 *  本機可放在 functions/.env，正式請用：
 *    firebase functions:params:set MODEL_BASE_URL="..."
 *    firebase functions:secrets:set MODEL_API_KEY
 */
const MODEL_BASE_URL = defineString("MODEL_BASE_URL");       // 宣告一個「字串參數」，取值順序：本機 .env → GCP Param
const MODEL_API_KEY = defineSecret("MODEL_API_KEY");         // 宣告一個「Secret 參數」，正式環境從 Secret Manager 取值(Firebase的)

admin.initializeApp();                                       // 初始化 Admin SDK（必須先做，才能用 Firestore/Auth）
const db = admin.firestore();                                // 取得 Firestore 客戶端

const app = express();                                       // 建立一個 Express 應用
app.use(cors({ origin: true }));                             // 啟用 CORS，允許瀏覽器/行動裝置跨網域請求
app.use(express.json());                                     // 讓 Express 能自動解析 JSON 請求內容 req.body

const SOURCE_REFUSAL = "【抱歉，與您的穿搭或是聊天訊息無關】"; // 你規格要求：凡問資料來源/訓練資料，一律回這句，僅目前想法，後面設定那邊還是要註明出處

/* -------------------------- Auth：驗證 Firebase idToken(這部分gpt寫的，我不太知道idToken) -------------------------- */
async function verifyAuth(req: Request): Promise<string | null> { // 驗證 HTTP Header 是否帶 Firebase idToken，回傳 uid
  const auth = req.headers.authorization;                 // 從 Header 讀 Authorization 欄位
  if (!auth?.startsWith("Bearer ")) return null;          // 沒帶或格式不對 → 不通過
  const token = auth.substring(7);                         // 把 "Bearer " 去掉，得到純 token 字串
  try {
    const decoded = await admin.auth().verifyIdToken(token); // 後端用 Admin SDK 驗證此 token
    return decoded.uid;                                   // 成功 → 取得使用者 uid
  } catch {
    return null;                                          // 驗證失敗 → 回 null
  }
}

/* ----------------------------- 配額控制（Firestore） ----------------------------- */
type Counter = {                                           // 定義資料結構：放在 Firestore 的使用量紀錄
  firstSignInAt: admin.firestore.Timestamp;                // 第一次登入時間（用來計算首月免費）
  dailyDate: string;        // YYYY-MM-DD                   // 今日日期字串（用來跨天重置）
  dailyChats: number;       // 今日聊天次數                 // 每天限制 2 次
  currentChatTurns: number; // 當前對話句數（用戶+AI）      // 每次對話限制 100 句（用戶一句 + AI 一句 = 2 句）
};

function todayStr(tz = "Asia/Taipei") {                    // 取得今天（台北時區）的 YYYY-MM-DD 字串
  return new Intl.DateTimeFormat("en-CA", { timeZone: tz }).format(new Date()); // e.g. "2025-09-10"
}

async function checkAndCount(                              // 核心：檢查是否超出配額，並且累加計數
  uid: string,                                             // 哪個使用者
  opts: { addTurns?: number; newChat?: boolean }           // addTurns：這次要加幾句、newChat：是否視為「新的一次聊天」
) {
  const ref = db.collection("users").doc(uid).collection("counters").doc("usage"); // 記錄路徑：/users/{uid}/counters/usage
  await db.runTransaction(async (tx: FirebaseFirestore.Transaction) => {           // 交易，避免併發寫入造成錯誤累加
    const snap = await tx.get(ref);                           // 讀現在的使用量
    const nowStr = todayStr();                                // 今日日期
    const now = admin.firestore.Timestamp.now();              // 現在時間（Timestamp）

    let c: Counter;
    if (!snap.exists) {                                       // 第一次使用 → 建立初始值
      c = {
        firstSignInAt: now,
        dailyDate: nowStr,
        dailyChats: 0,
        currentChatTurns: 0,
      };
    } else {
      c = snap.data() as Counter;                             // 已存在 → 取出
      // 跨天重置
      if (c.dailyDate !== nowStr) {                           // 如果紀錄的日子不是今天 → 表示已經跨天
        c.dailyDate = nowStr;
        c.dailyChats = 0;                                     // 今日次數歸零
        c.currentChatTurns = 0;                               // 今日句數歸零
      }
    }

    // 首月免費（需要可在此加入訂閱判斷）
    const freeUntil = new Date(c.firstSignInAt.toDate());     // 轉 JS Date
    freeUntil.setDate(freeUntil.getDate() + 30);              // 首月 = 註冊日起 + 30 天
    const inFreeMonth = freeUntil > new Date();               // 現在是否仍在首月
    // 若要強制訂閱才能使用，把上面 inFreeMonth 與你的訂閱狀態一起判斷（此處先不強制）

    if (opts.newChat && c.dailyChats >= 2) {                  // 若這次當作「新一次聊天」，但今天已經 2 次 → 擋掉
      throw new Error("今日免費次數已用完（每天 2 次）");
    }
    if ((c.currentChatTurns + (opts.addTurns ?? 0)) > 100) {  // 若加上這次要增加的句數超過 100 → 擋掉
      throw new Error("本次對話已達上限，可進化為Sugar Daddy!");
    }

    if (opts.newChat) c.dailyChats += 1;                      // 通過 → 若是新聊天，今日次數 +1
    if (opts.addTurns) c.currentChatTurns += opts.addTurns;   // 通過 → 句數 + addTurns

    tx.set(ref, c, { merge: true });                          // 寫回 Firestore（merge：只更新給定欄位）
  });
}

/* ----------------------------- 回傳解析（防呆多型）(這也是gpt的功勞) ----------------------------- */
function pickTextFromModelResponse(data: any): string {       // 從各種不同模型回應格式裡「挑出文字」
  // 1) OpenAI / 相容：chat.completions
  if (data?.choices?.length) {                                // 大多數 OpenAI 相容會有 choices 陣列
    const c = data.choices[0];

    // OpenAI: choices[0].message.content
    if (c?.message?.content) return c.message.content;        // 標準 chat.completions

    // 部分相容實作：choices[0].text
    if (typeof c?.text === "string") return c.text;           // 有些服務只回 text

    // 多模態：message.content 為陣列
    if (Array.isArray(c?.message?.content)) {                 // 圖文混合時，content 可能是陣列
      const parts = c.message.content
        .filter((p: any) => p?.type === "text" && typeof p?.text === "string")
        .map((p: any) => p.text);
      if (parts.length) return parts.join("\n");              // 把文字片段串起來
    }
  }

  // 2) 直接回字串
  if (typeof data === "string") return data;                  // 有些 API 直接回字串

  // 3) 常見替代鍵名
  if (typeof data?.output_text === "string") return data.output_text; // 常見替代鍵
  if (typeof data?.result === "string") return data.result;
  if (typeof data?.message === "string") return data.message;

  // 4) HF / vLLM 等
  const hf = data?.data?.[0]?.generated_text ?? data?.generated_text; // HuggingFace / vLLM 常見鍵
  if (typeof hf === "string") return hf;

  // 5) 保底：序列化
  try {
    return JSON.stringify(data);                               // 都沒有 → 直接把物件轉成字串給前端看清格式
  } catch {
    return "…";
  }
}

/* ----------------------------- 模型呼叫抽象層(簡單說，留了我們模型得位置在這，呼叫時改這部分即可，不排除前面需要import其他東西，中間層應該不用動) ----------------------------- */
/** 若未設定 MODEL_BASE_URL → 回 echo（測試用）。
 *  若已設定：假設你的端點支援「OpenAI 相容 chat.completions」。
 */
async function callModel(prompt: string, imageUrl?: string): Promise<string> { // 統一封裝：給我 prompt（可選 image），回你文字
  const base = MODEL_BASE_URL.value();                         // 讀取模型 API 的 Base URL（本機 .env 或雲端 Param）(.env絕對不能刪除)
  if (!base) {
    // 無模型：先回 echo，方便前端先打通流程
    return `（測試回覆）你說：「${prompt}」`;                // 你還沒接 Cloud Run 前，回這個
  }

  const apiKey = MODEL_API_KEY.value() || "";                  // 讀 Secret（若沒設定可為空）
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (apiKey) headers["Authorization"] = `Bearer ${apiKey}`;   // 若需要金鑰，放在 Authorization

  // 預設使用 OpenAI 相容 body
  const body: any = {
    model: "your-model-id",                                    // 你 Cloud Run 服務內部的模型名稱（之後改成真實）
    temperature: 0.7,                                          // 出文的隨機度（可調）
    messages: [{ role: "user", content: prompt }],             // Chat 形式的訊息陣列
  };

  if (imageUrl) {                                              // 若有傳圖片（例如 outfit）
    body.messages = [                                          // 使用圖文混合格式（OpenAI 規格）
      {
        role: "user",
        content: [
          { type: "text", text: prompt },
          { type: "image_url", image_url: { url: imageUrl } },
        ],
      },
    ];
  }

  const url = `${base.replace(/\/+$/, "")}/v1/chat/completions`; // 預設打 OpenAI 相容的 chat.completions 路徑
  const resp = await fetch(url, { method: "POST", headers, body: JSON.stringify(body) }); // 用 Node18 內建 fetch 發請求

  if (!resp.ok) {                                              // 若 HTTP 非 2xx → 丟錯，裡面包含狀態碼與伺服器回應
    const txt = await resp.text();
    throw new Error(`模型錯誤：${resp.status} ${txt}`);
  }

  const data = await resp.json();                              // 解析 JSON 回應
  return pickTextFromModelResponse(data);                      // 從回應裡面「挑出純文字」回給前端
}

/* --------------------------------- /chat --------------------------------- */
app.post("/chat", async (req: Request, res: Response) => {     // 定義 POST /chat 端點
  const uid = await verifyAuth(req);                           // 檢查 Authorization: Bearer <idToken>
  if (!uid) return res.status(401).json({ error: "unauthenticated" }); // 沒通過 → 401

  const { message, newChat } = req.body ?? {};                 // 從 body 抓 message 與 newChat
  try {
    await checkAndCount(uid, { newChat: !!newChat, addTurns: 2 }); // 每次聊天來回各 1 句 → 一次加 2 句

    const guard =
      "若用戶詢問資料來源/訓練集/隱私等，一律只回：" + SOURCE_REFUSAL; // 你的「資料來源一律拒答」規則

    const reply = await callModel(`${guard}\n\n使用者：${String(message ?? "")}`); // 呼叫模型（或 echo）
    res.json({ reply });                                       // 回覆 JSON：{ reply: "..." }
  } catch (e: any) {
    res.status(429).json({ error: e?.message ?? String(e) });  // 超限或其他錯誤 → 429（Too Many Requests）
  }
});

/* -------------------------------- /outfit -------------------------------- */
app.post("/outfit", async (req: Request, res: Response) => {   // 定義 POST /outfit 端點（穿搭 + 圖片）
  const uid = await verifyAuth(req);                           // 一樣要驗證 idToken
  if (!uid) return res.status(401).json({ error: "unauthenticated" });

  const { prompt, image_base64, newChat } = req.body ?? {};    // 從 body 抓文字描述與 base64 圖片
  try {
    await checkAndCount(uid, { newChat: !!newChat, addTurns: 2 }); // 一次互動仍然加 2 句

    const guard =
      "你是造型顧問：請給出具體建議（色彩、版型、場合、鞋包搭配），" +
      "並附 2~3 個台灣常見購買連結。若問資料來源/訓練集，回：" + SOURCE_REFUSAL; // 穿搭專用系統規則

    let imageUrl: string | undefined;
    if (image_base64) {
      imageUrl = `data:image/jpeg;base64,${image_base64}`;     // 先用 data URL（簡單好用；未來可改傳 Storage URL）
    }

    const reply = await callModel(`${guard}\n\n需求：${String(prompt ?? "")}`, imageUrl); // 呼叫模型（或 echo）
    res.json({ reply });                                       // 回 JSON
  } catch (e: any) {
    res.status(429).json({ error: e?.message ?? String(e) });  // 超限或其他錯誤
  }
});

/* ----------------------------- /admin/wipeUserData ----------------------------- */
/** 管理員清除使用者計數（選用）。
 *  TODO：加上你的管理員驗證（自訂 Claims / App Check / IP 白名單）
 */
app.post("/admin/wipeUserData", async (req: Request, res: Response) => { // 定義 POST /admin/wipeUserData
  const { uid } = req.body ?? {};                          // 從 body 取目標 uid
  if (!uid) return res.status(400).json({ error: "uid required" });

  const batch = db.batch();                                // 建立批次寫入
  batch.delete(db.collection("users").doc(uid).collection("counters").doc("usage")); // 刪除該 uid 的使用量紀錄
  await batch.commit();                                    // 送出批次

  res.json({ ok: true });                                  // 告知成功
});

/* ------------------------------- 匯出雲端函式 ------------------------------- */
export const api = onRequest(                              // 把 Express app 包成一個 HTTPS Cloud Function
  { secrets: [MODEL_API_KEY] },                            // 告訴平台：這個函式會用到哪些 Secret（部署時才會注入）
  app                                                      // 傳入 Express app
);
