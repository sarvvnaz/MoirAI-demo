# 🧠 MoirAI Research Demo  
**Detecting Idle Time & Generating Episodic Future Thinking (EFT) Nudges to Reduce Academic Procrastination**

---

## 🌍 Overview

**MoirAI** is an experimental research project exploring how **AI-driven episodic future thinking (EFT)** can help reduce **delay discounting** and **academic procrastination**.  
It detects periods of **user inactivity ("idle time")** and delivers **personalized motivational nudges** based on the user's goals and psychological profile — helping them reconnect short-term actions with long-term aspirations.

This project demonstrates how **behavioral science** and **machine intelligence** can combine to create real-time interventions for improving focus, motivation, and time consistency.

---

## 🧩 Core Features

- ⏱️ **Idle Time Detection:**  
  Monitors user activity and detects when attention drifts or productivity stalls.

- 🧠 **Episodic Future Thinking (EFT) Nudges:**  
  Generates personalized future-oriented reflections to reduce impulsivity and refocus users on their goals.

- 🎯 **Goal-Linked Sessions:**  
  Each session connects to a personal or academic goal, enabling data-driven progress tracking.



- 💬 **AI-Generated Nudges (OpenAI / LLM backend):**  
  Contextual motivational messages and reframing suggestions based on user state and goal type.

---

## 🏗️ Architecture

The system is built using a **Flutter + FastAPI** stack for modular experimentation:

| Component | Technology | Description |
|------------|-------------|-------------|
| Frontend | Flutter (Dart) | Cross-platform UI for focus sessions, check-ins, and nudges |
| Backend | FastAPI (Python) | REST API for session management, nudge generation, and data logging |
| Database | SQLite / PostgreSQL | Stores user profiles, sessions, and nudge logs |
| AI Layer | Groq API / LLM Integration | Generates personalized EFT-based nudges |
| Idle Detection | OS + App Monitors | Tracks window/app usage to infer idle states |

---

## ⚙️ Installation

### 1️⃣ Clone the repository
```bash
git clone https://github.com/sarvvnaz/MoirAI.git
cd MoirAI
