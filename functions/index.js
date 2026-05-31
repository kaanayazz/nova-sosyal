require("dotenv").config();

const {setGlobalOptions} = require("firebase-functions");
const {onCall, onRequest, HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const Iyzipay = require("iyzipay");

setGlobalOptions({maxInstances: 10});

admin.initializeApp();

const db = admin.firestore();

function getIyzipay() {
  return new Iyzipay({
    apiKey: process.env.IYZICO_API_KEY || "test",
    secretKey: process.env.IYZICO_SECRET_KEY || "test",
    uri:
      process.env.IYZICO_BASE_URL ||
      "https://sandbox-api.iyzipay.com",
  });
}

function moneyToString(value) {
  return (Number(value || 0)).toFixed(2);
}

exports.createIyzicoPayment = onCall(async (request) => {
const iyzipay = getIyzipay();
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Giriş yapmalısın.");
  }

  const uid = request.auth.uid;
  const userEmail = request.auth.token.email || "user@nova.app";

  const cartSnap = await db
    .collection("users")
    .doc(uid)
    .collection("cart")
    .get();

  if (cartSnap.empty) {
    throw new HttpsError("failed-precondition", "Sepet boş.");
  }

  const items = [];
  let total = 0;

  cartSnap.docs.forEach((doc) => {
    const data = doc.data();
    const price = Number(data.price || 0);
    const quantity = Number(data.quantity || 1);
    const lineTotal = price * quantity;

    total += lineTotal;

    items.push({
      id: data.productId || doc.id,
      name: data.title || "NOVA Ürün",
      category1: data.category || "NOVA Mağaza",
      itemType: Iyzipay.BASKET_ITEM_TYPE.PHYSICAL,
      price: moneyToString(lineTotal),
    });
  });

  if (total <= 0) {
    throw new HttpsError("failed-precondition", "Sepet toplamı geçersiz.");
  }

  const orderRef = db.collection("orders").doc();

  await orderRef.set({
    userId: uid,
    userEmail,
    items: cartSnap.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    })),
    total,
    paymentStatus: "pending",
    provider: "iyzico",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const paymentRequest = {
    locale: Iyzipay.LOCALE.TR,
    conversationId: orderRef.id,
    price: moneyToString(total),
    paidPrice: moneyToString(total),
    currency: Iyzipay.CURRENCY.TRY,
    basketId: orderRef.id,
    paymentGroup: Iyzipay.PAYMENT_GROUP.PRODUCT,
    callbackUrl: `${process.env.FUNCTIONS_BASE_URL}/iyzicoCallback`,
    enabledInstallments: [1],
    buyer: {
      id: uid,
      name: request.data?.buyerName || "NOVA",
      surname: request.data?.buyerSurname || "Kullanıcı",
      gsmNumber: request.data?.phone || "+905350000000",
      email: userEmail,
      identityNumber: request.data?.identityNumber || "11111111111",
      lastLoginDate: "2026-01-01 12:00:00",
      registrationDate: "2026-01-01 12:00:00",
      registrationAddress: request.data?.address || "Türkiye",
      ip: request.rawRequest.ip || "85.34.78.112",
      city: request.data?.city || "Istanbul",
      country: "Turkey",
      zipCode: request.data?.zipCode || "34000",
    },
    shippingAddress: {
      contactName: request.data?.contactName || "NOVA Kullanıcı",
      city: request.data?.city || "Istanbul",
      country: "Turkey",
      address: request.data?.address || "Türkiye",
      zipCode: request.data?.zipCode || "34000",
    },
    billingAddress: {
      contactName: request.data?.contactName || "NOVA Kullanıcı",
      city: request.data?.city || "Istanbul",
      country: "Turkey",
      address: request.data?.address || "Türkiye",
      zipCode: request.data?.zipCode || "34000",
    },
    basketItems: items,
  };

  return await new Promise((resolve, reject) => {
    iyzipay.checkoutFormInitialize.create(paymentRequest, async (err, result) => {
      if (err) {
        reject(new HttpsError("internal", err.message || "iyzico hatası"));
        return;
      }

      if (!result || result.status !== "success") {
        reject(
          new HttpsError(
            "internal",
            result?.errorMessage || "iyzico ödeme başlatılamadı"
          )
        );
        return;
      }

      await orderRef.update({
        iyzicoToken: result.token,
        paymentPageUrl: result.paymentPageUrl || "",
        checkoutFormContent: result.checkoutFormContent || "",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      resolve({
        orderId: orderRef.id,
        token: result.token,
        paymentPageUrl: result.paymentPageUrl,
        checkoutFormContent: result.checkoutFormContent,
      });
    });
  });
});

exports.iyzicoCallback = onRequest(async (req, res) => {
const iyzipay = getIyzipay();
  const token = req.body.token || req.query.token;

  if (!token) {
    res.status(400).send("Token yok");
    return;
  }

  const retrieveRequest = {
    locale: Iyzipay.LOCALE.TR,
    token,
  };

  iyzipay.checkoutForm.retrieve(retrieveRequest, async (err, result) => {
    if (err || !result) {
      res.status(500).send("Ödeme sonucu alınamadı");
      return;
    }

    const orderId = result.conversationId;

    if (orderId) {
      await db.collection("orders").doc(orderId).set(
        {
          paymentStatus: result.paymentStatus === "SUCCESS" ? "paid" : "failed",
          iyzicoResult: result,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true}
      );
    }

    res.send("Ödeme sonucu alındı. NOVA uygulamasına dönebilirsin.");
  });
});