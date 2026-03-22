# 8-bit RISC Processor Design (Verilog)

פרויקט זה מציג תכנון ומימוש של מעבד 8-ביט בארכיטקטורת RISC (Reduced Instruction Set Computer) באמצעות שפת Verilog. הפרויקט מתמקד בבנייה מודולרית של רכיבי החומרה ואימותם באמצעות סימולציות דיגיטליות.

## 🚀 מצב הפרויקט (Current Status)
נכון לעכשיו, הושלם שלב הפיתוח והאימות של רכיבי הליבה (Core Components). כל רכיב נבדק בנפרד (Unit Testing) ונמצא תקין בסימולציות גלים.

### רכיבים שמומשו:
* **ALU (Arithmetic Logic Unit)**: יחידה לביצוע פעולות אריתמטיות (חיבור, חיסור) ולוגיות (AND, OR, XOR).
* **Register File**: מערך אוגרים פנימי (8x8-bit) המאפשר קריאה של שני אוגרים וכתיבה לאוגר אחד במקביל.
* **Program Counter (PC)**: מונה תוכנית 8-ביט עם מנגנון איפוס אסינכרוני (Asynchronous Reset).
* **Instruction Memory (IMEM)**: זיכרון לקריאה בלבד (ROM) בנפח 256 בתים, התומך בטעינת תוכנה מקובץ חיצוני (`program.hex`).

## 📂 מבנה הפרויקט (Project Structure)
הפרויקט מאורגן בהפרדה ברורה בין קוד המקור (Source) לבין סביבת הבדיקה (Tests):

```text
.
├── src/                # קבצי המקור של המעבד (Design)
│   ├── alu.v           # יחידה אריתמטית-לוגית
│   ├── regfile.v       # קובץ אוגרים פנימי
│   ├── pc.v            # מונה תוכנית (Program Counter)
│   └── imem.v          # זיכרון פקודות (Instruction Memory)
├── tests/              # סביבת בדיקה ואימות (Verification)
│   ├── tb_alu.v
│   ├── tb_regfile.v
│   ├── tb_pc.v
│   └── tb_imem.v
├── program.hex         # קובץ קוד מכונה (Hex) לטעינה לזיכרון
└── README.md