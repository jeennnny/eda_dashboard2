# Gapminder 데이터 분석 프로젝트

Gapminder 데이터셋(142개국 × 1952~2007년)을 **다운로드 → 품질 확인 → 정제 → 탐색적 분석(EDA)** 까지 수행하는 R 기반 분석 파이프라인입니다.

---

## 📁 프로젝트 구조

```
gapminder/
├── clean.R                       # 데이터 품질 확인 + 정제 스크립트
├── eda.R                         # 탐색적 데이터 분석 + 시각화 스크립트
├── README.md                     # (현재 문서)
├── data/
│   ├── gapminder.csv             # 원본 데이터 (다운로드)
│   ├── gapminder_clean.csv       # 정제본
│   └── quality_report.txt        # 품질 확인 텍스트 리포트
├── document/
│   ├── data_quality_report.md    # 품질 확인 보고서 (Markdown)
│   ├── eda_report.md             # EDA 보고서 (Markdown, 그림 포함)
│   └── eda_summary.txt           # EDA 요약 텍스트
└── figures/                      # EDA 시각화 8종 (PNG)
```

---

## 📊 데이터셋 개요

| 항목 | 내용 |
|---|---|
| 출처 | [plotly/datasets](https://github.com/plotly/datasets) (표준 Gapminder 5년 단위 데이터) |
| 규모 | 1,704행 × 6열 (142개국 × 12개 연도) |
| 기간 | 1952 ~ 2007 (5년 간격) |
| 컬럼 | `country`, `year`, `pop`, `continent`, `lifeExp`, `gdpPercap` |

---

## 🚀 실행 방법

> R 4.6.0 기준. `clean.R`은 base R만, `eda.R`은 `ggplot2`, `dplyr`, `tidyr`를 사용합니다.

```bash
# 1) 데이터 품질 확인 + 정제본 생성
Rscript clean.R

# 2) 탐색적 분석 + 시각화 생성
Rscript eda.R
```

Windows에서 `Rscript`가 PATH에 없을 경우:

```powershell
& "C:\Program Files\R\R-4.6.0\bin\Rscript.exe" clean.R
& "C:\Program Files\R\R-4.6.0\bin\Rscript.exe" eda.R
```

---

## ✅ 1단계 · 데이터 품질 확인

스크립트 `clean.R` → 보고서 [document/data_quality_report.md](document/data_quality_report.md)

**종합 판정: 통과 (PASS)**

| 점검 항목 | 결과 |
|---|---|
| 결측치(NA) | 0건 |
| 완전 중복 / 키 중복 | 0건 / 0건 |
| 도메인 규칙 (pop>0, lifeExp 0~120, gdpPercap>0) | 위반 없음 |
| 패널 균형 | 142개국 모두 12개 연도 → 균형 패널 |

→ 추가 정제 없이 분석에 바로 사용 가능한 깨끗한 데이터.

---

## 🔍 2단계 · 탐색적 분석 (EDA)

스크립트 `eda.R` → 보고서 [document/eda_report.md](document/eda_report.md)

### 핵심 인사이트

1. **소득–건강의 강한 비선형 관계** — Spearman 0.826, 로그 1인당 GDP 상관 **0.808** (원시 Pearson 0.584는 과소평가). 고소득 구간 포화(Preston 곡선).
2. **"평균은 위험하다"** — "모든 대륙 상승"은 착시. 짐바브웨·스와질란드는 1952년보다 기대수명이 *하락*, 르완다는 단일 구간 -20.4년 급락(1994 학살). 대륙 평균은 인구가중 시 아시아 -1.3년으로 해석이 달라짐.
3. **수렴은 단정 불가** — 기대수명 분산(SD)은 12.2→12.1로 정체, GDP CV 감소는 쿠웨이트 이상치 영향.
4. **한계 명시** — 142개국·5년 간격, 상관일 뿐 인과 아님, 1인당 GDP는 국가 내 불평등 미반영.

### 대표 시각화

![Preston 곡선: GDP vs 기대수명](figures/04_preston_curve.png)

![기대수명 하락 국가 궤적](figures/06_lifeExp_reversals.png)

> 전체 시각화 9종은 [figures/](figures/) 폴더 및 [EDA 보고서](document/eda_report.md)에서 확인할 수 있습니다.

---

## 🛠️ 기술 스택

- **언어**: R 4.6.0
- **패키지**: ggplot2, dplyr, tidyr (EDA) / base R (품질 확인)

---

## 📄 산출물 요약

| 분류 | 파일 |
|---|---|
| 스크립트 | `clean.R`, `eda.R` |
| 데이터 | `data/gapminder.csv`, `data/gapminder_clean.csv` |
| 보고서 (MD) | `document/data_quality_report.md`, `document/eda_report.md` |
| 리포트 (TXT) | `data/quality_report.txt`, `document/eda_summary.txt` |
| 시각화 | `figures/*.png` (8종) |
