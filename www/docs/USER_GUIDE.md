# RapidCaseReport: User guide

**Audience:** health professionals and authorised staff submitting suspected-case reports  
**Documentation revision:** 23 November 2026

## 1. Purpose

RapidCaseReport lets you enter a suspected-case report, select its geographic area on a map, review the information, and submit it. Successfully submitted reports are saved to the application's data store. You can inspect and download the reports you entered during the current browser session.

You do not need to configure a database or modify application files. Contact your institution's administrator if the app is unavailable, geographic options do not load, or you need access to older institutional records.

## 2. Screen layout

| Section | What you enter or see |
|---|---|
| **General Information** | Consultation date, sex, and birth date. |
| **Location** | Country, first/second administrative levels, and the finest area chosen on the map. |
| **Symptoms** | Date symptoms began and a free-text symptom description. |
| **Suspected Diagnosis** | The suspected diagnosis in free text. |
| **Professional Information** | Your email and institution. |
| **Location map** | Detailed area boundaries; click the correct finest geographic area. |
| **Current session records** | A table of reports successfully saved in this session. |
| **Download Current Session CSV** | Export the records saved during the current session. |

The exact province/department/fraction labels depend on the country configured by your institution.

## 3. Enter a report

1. In **General Information**, select the consultation date, sex, and birth date. Verify the birth date is not later than the consultation date.
2. In **Location**, select the country, then the first and second available administrative levels. These lists change based on the parent area.
3. On **Location map**, click the correct finest area. The selected identifier should appear in **Selected Area (ID)**. Merely choosing a department does not complete the location.
4. Enter the symptom onset date and describe the symptoms. Use clear clinical terminology and avoid unnecessary identifying details in free text.
5. Enter the suspected diagnosis.
6. Enter your professional email and institution.
7. Select **Submit Report**.
8. Review the **Confirm Submission** dialog carefully. If something is wrong, cancel, correct it, and start the submission step again. Select **Confirm** only when all information is accurate.

The application checks required fields, email format, the selected geographic area and whether birth date is after consultation date. It does not check every relationship between symptom-onset and consultation dates. Review the dates before confirming a report.

## 4. After confirmation

A successful write shows **Submission successful**. The saved report appears in *Current session records*. The form resets the main patient/clinical fields for the next case, but keeps the previously selected location and professional fields. Check them before submitting a different case, particularly when location or reporter changes.

If a write fails, the application shows **Submission failed. Please try again.** The failed record should not be added to the current session table. Before trying again, check with your institution if you are unsure whether the report was persisted.

Reports cannot be edited from this form after submission. Contact the administrator to correct a confirmed error using your institution's approved procedure.

## 5. Downloading current-session data

Select **Download Current Session CSV** below the session table. The file includes the records successfully saved **during this active session**, with fields such as the case identifier, dates, geography, symptoms, diagnosis and reporting details.

This action **does not** download every report in the database, earlier sessions, or records submitted by a particular email address. Closing or restarting the browser session resets the on-screen session list even though previously confirmed reports remain in the institution's data store.

Downloaded files may contain sensitive health and reporter information. Store and share them only through approved institutional channels.

## 6. Common problems

| Problem | Recommended response |
|---|---|
| Country or administrative list is empty | Contact the administrator; geographic data may be unavailable. |
| Finest area field says **Select on the map** | Click a visible finest-area polygon before submitting. |
| Wrong area highlighted | Use **Reset locations**, reselect the country and parent levels, then click again. |
| Validation dialog appears | Review the displayed required/invalid fields and correct them. |
| Submit succeeds but inputs reset | Expected for selected patient/clinical fields; session table keeps successful entries. |
| No earlier records appear in the table | Expected: it displays records from the current session only. |
| Submission fails | Avoid repeated attempts until the error is checked by your administrator. |

### Use consistent clinical terms

Describe symptoms and suspected diagnoses clearly. Follow your institution’s preferred terminology where available, and avoid unnecessary personal details in free-text fields. Different spellings and abbreviations can make later searches and summaries less reliable.

## 7. Reporting quality and confidentiality

Do not interpret a submitted suspected case as a confirmed diagnosis. Check locations, dates and entered text before confirmation. Follow organisational policies for data confidentiality, secure exports, retention and authorised access. For application errors or corrections to saved reports, use your institution's support process.
