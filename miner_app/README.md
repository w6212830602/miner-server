# BTC Miner Monitor

A proof-of-concept cross-platform tool for scanning and monitoring Bitcoin miners on a local network.

This project was built as part of a technical interview task to demonstrate learning a new tech stack, system design, and development workflow within a limited timeframe.

---

## Tech Stack

- Frontend: Flutter
- Backend: Go

---

## Overview

The goal of this project is to replicate the core functionality of tools like BTC Tools, focusing on:

- Scanning a local IP or IP range
- Detecting miner online/offline status
- Displaying results in a simple, demo-friendly UI

The scope is intentionally limited to ensure reliability and clarity during the demo.

---

## Architecture

**Backend (Go)**
- Handlers → Services → Clients → Models
- Concurrent scanning with configurable timeouts
- Supports real or mock miner clients

**Frontend (Flutter)**
- Models, services, screens, and reusable widgets
- Simple state handling (loading, error, results)

---

## Running the Project

### Backend
```bash
cd backend
go run main.go


### Frontend
cd miner_app
flutter pub get
flutter run
