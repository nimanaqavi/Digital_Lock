# 🔐 Behavioral Biometric Security Lock (ATmega64)

![Platform](https://img.shields.io/badge/platform-AVR-blue)
![Language](https://img.shields.io/badge/language-Assembly-red)
![MCU](https://img.shields.io/badge/MCU-ATmega64-green)
![Status](https://img.shields.io/badge/status-Completed-success)

## 🚀 Overview
An advanced, two-tier (User/Admin) digital security lock system implemented in **AVR Assembly** for the **ATmega64 microcontroller**. 

This project enhances traditional password systems by introducing a **behavioral timing pattern** as an additional security layer. Unlike standard locks that rely solely on binary passwords, this system verifies:
* **User ID** (up to 16 users).
* **Binary password pattern** (4-bit sequence of 0s and 1s).
* **Timing intervals** between key presses (Behavioral Signature).

This transforms the password into a personal behavioral signature, making unauthorized access extremely difficult even if the binary code is compromised.

## ⭐ Key Features
* **Multi-User Management:** Capacity to store and manage up to 16 unique users (IDs 0 to 15).
* **Behavioral Biometrics:** Records and verifies the exact rhythm of a 4-bit input pattern.
* **Persistent Storage:** Uses EEPROM to retain user IDs, binary patterns, and interval data safely during power loss.
* **State Machine Architecture:** Operates on a structured state machine with `IDLE`, `ADMIN`, and `USER` states.
* **Strict Admin Authentication:** Entering Admin mode requires a specific hardware key combination and precise timing verification.

## 🧠 Technical Implementation

### Timing Analysis & Tolerance
The system captures the time elapsed between key presses using **Timer 0**. 
* **Clock Configuration:** The MCU runs at `f_osc = 1.024MHz` with a prescaler of 1024, yielding a 1ms timer clock.
* **Timer Interrupts:** The timer's initial value is set to 206, generating an interrupt every 50ms.
* **Tolerance Logic:** To account for human inconsistency, a timing tolerance is implemented. The system accepts inputs where the time difference is less than or equal to 1000ms:
  `|T_input - T_stored| <= Tolerance`
  Where the `Tolerance` is calculated as `20 * 50ms` units.

### Admin Authentication
To register new users, the Admin must pass a timing-based hardware challenge:
1. Input a specific wait-time value via PORT B.
2. Press INT5.
3. Wait exactly the number of seconds inputted in step 1, then press INT5 again.

## 🧱 Hardware Configuration

### Port Mapping
* **PORT B (Input):** Used for User ID entry (0-15) and the Admin hardware key (`DDRB = 0x00`).
* **PORT C (Output):** Controls system status LEDs (`DDRC = 0xFF`).

### Status LEDs (PORT C)
| Pin | Color | Function |
| :--- | :--- | :--- |
| PC0 | White | IDLE Mode / Waiting |
| PC1 | Red | Error / Admin Mode active |
| PC2 | Green/Blue | Success / Entry allowed |
| PC6 | Yellow | User input waiting |
| PC7 | Purple | USER Mode active |

### Interrupt Architecture
The core logic relies on external interrupts to capture real-time data.

| Interrupt | Function |
| :--- | :--- |
| **INT0** | Enter bit `0` into the pattern |
| **INT1** | Enter bit `1` into the pattern |
| **INT2** | Switch to USER mode |
| **INT3** | Switch to ADMIN mode |
| **INT4** | Confirm (Enter) ID or Pattern |
| **INT5** | Admin hardware authentication process |

## 📂 Project Structure
```text
project-root
│
├── Digital_LOCK/        # AVR Assembly source files (.asm)
├── Proteus/             # Proteus simulation files (.pdsprj)
└── Docs/                # Project reports and requirement docs

## 🧪 Simulation
This system was fully modeled, simulated, and verified using **Proteus**. 
*(Insert Proteus schematic screenshot here)*

## 📜 License
Educational project — free to use for learning purposes.
