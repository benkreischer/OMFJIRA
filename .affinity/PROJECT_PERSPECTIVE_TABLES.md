# Project Perspective Connection Tables
## Formatted Like Affinity Diagram Lower-Left Tables

Based on analysis of the connection data, here are the formatted tables for each project perspective:

## TOKR (Token Services) - 18 Direct Connections

| Source→Target | Connections | Direct Links | Total Links |
|---------------|-------------|--------------|-------------|
| TOKR→QUAL     | 7          | 91           | 116         |
| TOKR→PAY      | 6          | 1669         | 1835        |
| TOKR→LAS      | 6          | 127          | 166         |
| TOKR→COL      | 6          | 9            | 36          |
| TOKR→OAE      | 6          | 5            | 105         |
| TOKR→CES      | 4          | 640          | 747         |
| TOKR→ENGOPS   | 4          | 58           | 88          |
| TOKR→MOB      | 4          | 21           | 42          |
| TOKR→DBEAN    | 4          | 12           | 90          |
| TOKR→IMG      | 4          | 2            | 337         |
| TOKR→PDS      | 4          | 2            | 15          |
| TOKR→COR      | 3          | 15           | 37          |
| TOKR→DAWA     | 3          | 3            | 33          |
| TOKR→FORMS    | 3          | 3            | 49          |
| TOKR→BINT     | 3          | 1            | 11          |
| TOKR→DARC     | 2          | 10           | 13          |
| TOKR→CIA      | 2          | 4            | 1296        |
| TOKR→SIGN     | 1          | 1            | 13          |

**Totals**: 18 connections, 2673 total links

---

## PAY (Payments) - 8 Direct Connections

| Source→Target | Connections | Direct Links | Total Links |
|---------------|-------------|--------------|-------------|
| PAY→TOKR      | 6          | 1669         | 2673        |
| PAY→OAE       | 4          | 23           | 105         |
| PAY→OBSRV     | 4          | 120          | 1090        |
| PAY→CES       | 3          | 3            | 747         |
| PAY→TRIM      | 2          | 1            | 121         |
| PAY→FORMS     | 1          | 1            | 49          |
| PAY→UPT       | 1          | 3            | 256         |
| PAY→DBEAN     | 1          | 15           | 90          |

**Totals**: 8 connections, 1835 total links

---

## EOKR (Engineering OKRs) - 12 Direct Connections

| Source→Target | Connections | Direct Links | Total Links |
|---------------|-------------|--------------|-------------|
| EOKR→CIA      | 4          | 1265         | 1296        |
| EOKR→UPT      | 4          | 225          | 256         |
| EOKR→UX       | 4          | 2            | 24          |
| EOKR→OAE      | 4          | 1            | 105         |
| EOKR→ACQE     | 3          | 110          | 330         |
| EOKR→ACQ      | 3          | 92           | 129         |
| EOKR→ONE      | 3          | 22           | 35          |
| EOKR→TRIM     | 2          | 120          | 121         |
| EOKR→UN       | 2          | 3            | 27          |
| EOKR→CARD     | 1          | 2            | 116         |
| EOKR→AUT      | 1          | 1            | 111         |
| EOKR→IAM      | 1          | 1            | 22          |

**Totals**: 12 connections, 1844 total links

---

## CIA (Customer Information Analytics) - 9 Direct Connections

| Source→Target | Connections | Direct Links | Total Links |
|---------------|-------------|--------------|-------------|
| CIA→EOKR      | 4          | 1265         | 1844        |
| CIA→TOKR      | 2          | 4            | 2673        |
| CIA→UPT       | 2          | 27           | 256         |
| CIA→UX        | 2          | 2            | 24          |
| CIA→ACQE      | 1          | 10           | 330         |
| CIA→ACQ       | 1          | 2            | 129         |
| CIA→ONE       | 1          | 22           | 35          |
| CIA→AUT       | 1          | 1            | 111         |
| CIA→IAM       | 1          | 1            | 22          |

**Totals**: 9 connections, 1296 total links

---

## OBSRV (Observability) - 16 Direct Connections

| Source→Target | Connections | Direct Links | Total Links |
|---------------|-------------|--------------|-------------|
| OBSRV→PAY     | 4          | 120          | 1835        |
| OBSRV→UN      | 4          | 22           | 27          |
| OBSRV→UPT     | 3          | 3            | 256         |
| OBSRV→OAE     | 3          | 11           | 105         |
| OBSRV→TRIM    | 3          | 1            | 121         |
| OBSRV→CES     | 2          | 10           | 747         |
| OBSRV→UX      | 2          | 3            | 24          |
| OBSRV→EOKR    | 2          | 1            | 1844        |
| OBSRV→MOB     | 1          | 115          | 42          |
| OBSRV→PSM     | 1          | 22           | 22          |
| OBSRV→CARD    | 1          | 7            | 116         |
| OBSRV→POP     | 1          | 87           | 111         |
| OBSRV→OSO     | 1          | 87           | 91          |
| OBSRV→TOKR    | 1          | 1            | 2673        |
| OBSRV→EDME    | 1          | 1            | 388         |
| OBSRV→CISRE   | 1          | 1            | 6           |

**Totals**: 16 connections, 1090 total links

---

## Key Insights from Complete Matrix:

### **Mega-Connections (1000+ links)**:
1. **PAY → TOKR**: 1,669 links (91% of PAY's connections)
2. **EOKR → CIA**: 1,265 links (69% of EOKR's connections)

### **Hub Projects (6+ connections to central project)**:
- **TOKR hubs**: QUAL, PAY, LAS, COL, OAE (5 hub connections)
- **PAY hubs**: TOKR (1 hub connection)
- **EOKR hubs**: None (max 4 connections)

### **Project Specialization Patterns**:
- **TOKR**: Distributed connectivity (5 hubs, 6 high, 6 medium, 1 low)
- **PAY**: Highly concentrated (6 connections to TOKR, minimal elsewhere)
- **EOKR**: Engineering-focused (heavy CIA connection for analytics)
- **OBSRV**: Monitoring hub (16 connections, wide distribution)

---

*Note: Connection count = number of other projects this project connects to within the central project's network*
*Direct Links = actual issue link count between the two projects*
*Total Links = sum of all links for the target project*

**Data Source**: Issue Links - GET Project to Project Links - Filtered Unresolved 90Day
**Analysis Date**: September 30, 2025