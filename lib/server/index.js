// server/index.js
import express from 'express';
import cors from 'cors';
import bodyParser from 'body-parser';
import nodemailer from 'nodemailer';
import admin from 'firebase-admin';
import dotenv from "dotenv";

dotenv.config();
const app = express();
app.use(cors());
app.use(bodyParser.urlencoded({ extended: false }));
app.use(bodyParser.json());

// Initialize Firebase Admin
// Put your service account JSON path or env
admin.initializeApp({
    credential: admin.credential.applicationDefault(),
});
const db = admin.firestore();

// configure mail transport (use real creds or an app password)
const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
        user: process.env.MAIL_USER,   // your Gmail
        pass: process.env.MAIL_PASS,   // app password
    },
});

function genCode() {
    return Math.floor(10000 + Math.random() * 90000).toString(); // 5 digits
}

app.post('/send-otp', async (req, res) => {
    try {
        const { uid, email } = req.body;
        if (!uid || !email) return res.status(400).send('uid and email required');

        const code = genCode();
        const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5 minutes

        // store (plain for demo; hash in production)
        await db.collection('email_otps').doc(uid).set({
            email,
            code,
            expiresAt,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        await transporter.sendMail({
            from: `"iFeed" <${process.env.MAIL_USER}>`,
            to: email,
            subject: 'Your iFeed verification code',
            text: `Your verification code is: ${code}\nThis code expires in 5 minutes.`,
        });

        res.send('ok');
    } catch (e) {
        console.error(e);
        res.status(500).send('error');
    }
});

const PORT = process.env.PORT || 8080;
app.listen(PORT, () => console.log('OTP server running on', PORT));
