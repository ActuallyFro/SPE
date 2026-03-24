# Sinclair Program Explorer 🎓

An interactive dashboard for exploring and comparing Sinclair Community College associate degree programs against real-world labor market data (BLS & Ohio OEWS). This Single Page Application (SPA) helps students visualize career outcomes including salary, job growth, and AI impact.

[LIVE SITE HERE](http://actuallyfro.github.io/SPE/SinclairExplorer.html)

## 📋 Table of Contents

- [Helpful Resources](#-helpful-resources)
- [Features](#-features)
- [How to Run](#-how-to-run)
- [Data Management Workflow](#-data-management-tools)
  - [Editing Data](#1-interactive-data-editor)
  - [Deploying Updates](#2-merge-data-to-application)

## 🔗 Helpful Resources

*   **BLS Data:** [Occupational Outlook Handbook (A-Z Index)](https://www.bls.gov/ooh/a-z-index.html)
*   **Sinclair Resources:**
    *   [Associate Degree Programs List](https://www.sinclair.edu/academics/degrees/)
    *   [Brand Color Guide](https://www.sinclair.edu/about/offices/enrollment-strategy-office/brand-toolkit/colors/)
*   **Regional Data:** [Ohio OEWS 2024 Data](https://data.bls.gov/oes/#/area/3900000)

## ✨ Features

*   **Interactive Visualization**: Explore programs mapped by Salary vs. Growth.
*   **Sticky Tooltips**: Click dots to freeze detailed info cards; drag them to compare multiple programs side-by-side.
*   **Rich Data**: Includes Median Salary, Hourly Pay, Job Growth %, AI Impact, and Ohio-specific employment data.
*   **Filtering**: Filter by Interest Level, Salary, Growth, and more.

## 🚀 How to Run

This is a standalone Single Page Application (SPA).

1.  Navigate to the project folder.
2.  Open `SinclairExplorer.html` in your web browser (Chrome, Firefox, Edge).

No server installation or backend is required.

## 🛠️ Data Management Tools

This project includes a set of scripts to manage the dataset (`data/SinclairPrograms_Main.csv`) and sync it with the Single Page Application (`SinclairExplorer.html`).

### 1. Interactive Data Editor
Use this tool to safely edit the CSV file without breaking the format. It handles comma removal for numeric fields and ensuring safe text entry.

```bash
./scripts/UpdateEntry.sh
```

**Features:**
- Search by Program Title or select by Row Number.
- Edit multiple columns in a session.
- Validates inputs and handles comma stripping automatically.
- ACID-safe saving (prevents data corruption).

### 2. Merge Data to Application
After making changes to the CSV, you **MUST** run this script to update the HTML file. The data is embedded directly into the SPA to allow it to run offline without a backend.

```bash
bash scripts/Merge-new_Main-Data.sh
```

**What it does:**
- Reads `data/SinclairPrograms_Main.csv`.
- Parses all 21 data columns (including Ohio OEWS data & Education levels).
- Updates the `RAW_DATA` variable in `SinclairExplorer.html`.
