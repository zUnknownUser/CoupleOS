# CoupleOS

> A private digital world for two.

CoupleOS is an iOS app designed to give couples a shared space that feels personal, alive and truly theirs.

Instead of being just another relationship app with disconnected utilities, CoupleOS is built around a shared world where two people can connect, interact and progressively build experiences together.

---

## ✨ Vision

CoupleOS is not a dating app.

It is a private operating system for a relationship.

Two users connect to the same Couple World and share the same space in real time.

The goal is to make the relationship itself feel like a living digital environment, not just a collection of features.

---

## 🚀 Current Status

The core foundation is already working:

* Authentication
* Persistent user profiles
* Couple creation
* Secure invitations
* Deep links
* Shared Couple state
* Realtime updates
* Firebase backend
* Cloud Functions

The project is currently moving into the first version of the shared Home experience.

---

## 🛠 Tech Stack

* Swift
* SwiftUI
* The Composable Architecture
* Swift Concurrency
* Firebase Authentication
* Cloud Firestore
* Firebase Cloud Functions
* Firebase Cloud Messaging

---

## 🧩 Architecture

CoupleOS uses a feature-oriented architecture built around TCA.

The focus is on:

* clear state ownership
* unidirectional data flow
* testable features
* deterministic navigation
* explicit async effect lifecycle
* minimal coupling between domains

The project avoids unnecessary abstraction and keeps infrastructure isolated from UI whenever possible.

---

## 🌐 Core Flow

```text
User A
  │
  ├── creates Couple World
  │
  └── generates invite
            │
            ▼
         User B
            │
            └── accepts invite
                    │
                    ▼
             Shared Couple World
                    │
                    ▼
                 Realtime
```

---

## 🎨 Product Direction

The visual direction is:

* dark-first
* premium
* intimate
* modern
* slightly futuristic

The goal is to avoid the typical visual language of dating and couples apps.

CoupleOS should feel like a private digital environment built specifically for two people.

---

## 🧪 Testing

The backend includes automated tests for critical Couple and Invite flows.

Current backend status:

```text
14 tests
14 passing
0 failing
```

---

## ▶️ Running the Project

### Requirements

* Xcode
* iOS SDK
* Firebase project
* Firebase CLI
* Node.js for Cloud Functions

### iOS

Open the project in Xcode and resolve Swift Package Manager dependencies.

Add the Firebase configuration:

```text
GoogleService-Info.plist
```

Then run the app normally from Xcode.

### Firebase Functions

```bash
cd functions
npm install
firebase deploy --only functions
```

---

## 🗺 Roadmap

### Done

* Authentication
* User profiles
* Couple creation
* Invitations
* Deep links
* Shared Couple state
* Realtime foundation

### In progress

* Shared Home

### Next

* Daily shared interactions
* Push notifications
* Richer realtime experiences
* Shared content
* Personalization

---

## 📸 Screenshots

Coming soon.

---

## License

All rights reserved.
