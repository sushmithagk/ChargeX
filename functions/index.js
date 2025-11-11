const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();
const db = admin.firestore();

/*
 For now, we are only adding a test function to confirm that Cloud Functions is working.
 Once you confirm, we will replace it with the Charger API code.
*/

exports.testFunction = functions.https.onRequest((req, res) => {
  res.send("Cloud Functions working ✅");
});
