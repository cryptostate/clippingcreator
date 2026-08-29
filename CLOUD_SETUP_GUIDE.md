# 🚀 Clipping Creator — Cloud & Backend Setup Guide

Is guide me complete step-by-step instructions hain jisse aap **AssemblyAI**, **Google Cloud Platform (GCS & Firestore)**, aur **Firebase** setup kar sakte hain.

---

## 🔑 1. AssemblyAI API Key (Required for AI Pipeline)

AssemblyAI video ke audio ka transcription, auto-chapters, topic detection, sentiment analysis, aur viral highlights extract karne ke liye use hota hai.

1. [AssemblyAI Website](https://www.assemblyai.com/) par free account banayein.
2. Dashboard me **API Key** copy karein.
3. Is key ko apne `.env` me set karein:
   ```env
   ASSEMBLYAI_API_KEY=your_copied_api_key
   ```

---

## ☁️ 2. Google Cloud Platform (GCP) Setup (For Production Media & DB)

> **Note:** Development / Local testing ke liye humne **In-Memory Database & Local File Storage fallback** add kar diya hai, toh local testing bina GCP ke bhi ho jayegi. Lekin production / deployment ke liye ye setup zaroori hai.

### A. GCP Project Create karein:
1. [Google Cloud Console](https://console.cloud.google.com/) me jayein.
2. Ek naya project banayein: Example `clipping-creator-app`.
3. Project ID note karein: `GCP_PROJECT_ID=clipping-creator-app`.

### B. Cloud Storage (GCS) Bucket Create karein:
1. Console me **Cloud Storage** > **Buckets** par jayein.
2. **Create Bucket** par click karein.
3. Bucket ka naam rakhein (e.g. `clippingcreator-media-prod`).
4. Location: Apne region ke hisaab se select karein (e.g. `asia-south1` ya `us-central1`).
5. Is naam ko `.env` me daalein:
   ```env
   GCS_BUCKET_NAME=clippingcreator-media-prod
   ```

### C. Cloud Firestore Enable karein:
1. Console me **Firestore** search karein.
2. **Create Database** > **Native Mode** select karein.
3. Region select karein aur create karein.

### D. Service Account Credentials JSON:
1. **IAM & Admin** > **Service Accounts** me jayein.
2. **Create Service Account** par click karein (Name: `clipping-backend-sa`).
3. Is account ko Roles dein:
   - `Storage Admin` (Media files upload/download ke liye)
   - `Cloud Datastore User` (Firestore database read/write ke liye)
4. **Keys** tab me jaakar **Add Key** > **Create new key (JSON)** select karein.
5. JSON file download hogi (e.g. `gcp-credentials.json`).
6. Is file ka path `.env` me set karein:
   ```env
   GOOGLE_APPLICATION_CREDENTIALS=/path/to/gcp-credentials.json
   ```

---

## 🐳 3. Backend Run Karne Ka Tareeqa

### Option A: Local Python me Run karna
```bash
# 1. Backend folder me jayein
cd backend

# 2. Virtual environment create & activate karein
python -m venv venv
# Windows:
.\venv\Scripts\activate
# Mac/Linux:
source venv/bin/activate

# 3. Dependencies install karein
pip install -r requirements.txt

# 4. .env file create karein
copy .env.example .env

# 5. FastAPI server start karein
uvicorn backend.main:app --host 0.0.0.0 --port 8080 --reload
```

### Option B: Docker Container me Run karna
```bash
cd backend
docker build -t clipping-creator-backend .
docker run -p 8080:8080 --env-file .env clipping-creator-backend
```

---

## 📱 4. Flutter App Run Karne Ka Tareeqa

```bash
# 1. Dependencies install karein
flutter pub get

# 2. Android emulator ya device par run karein
flutter run

# Agar physical device par run kar rahe hain aur backend IP customize karni hai:
flutter run --dart-define=API_BASE_URL=http://YOUR_PC_IP:8080
```

---

## 📋 Summary of What We Fixed in the Codebase:
1. ✅ **Android Permissions & ClearText Traffic:** AndroidManifest.xml me INTERNET, Storage permissions aur ClearText HTTP access add kiya.
2. ✅ **Dynamic API Base URL:** Flutter ApiService ko platform-aware banaya (Android Emulator ke liye `10.0.2.2:8080`, Web/Desktop ke liye `localhost:8080`, custom override support).
3. ✅ **Real Download & Share Integration:** Export Screen me real download file save & native share sheet triggers add kiye.
4. ✅ **Zero-Config Local Backend Fallback:** Backend me Local in-memory Firestore & local disk storage fallback integrate kiya, jisse local dev bina GCP account ke bhi test ho sake.
5. ✅ **Cross-Platform FFmpeg Fonts:** Windows aur Linux/Docker dono par font auto-detection lagaya taaki subtitle burning crash na ho.
6. ✅ **Signed URLs for AssemblyAI:** AssemblyAI audio ingestion ko GCS Public Access restrictions se safe banaya.
