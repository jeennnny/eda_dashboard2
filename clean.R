# clean.R
# Gapminder 데이터 품질 확인(Quality Check) 스크립트
# 입력 : data/gapminder.csv
# 출력 : data/gapminder_clean.csv  (정제본)
#        data/quality_report.txt   (품질 리포트)
# 실행 : Rscript clean.R
# 의존성 없음 (base R 만 사용)

# ---- 0. 설정 ------------------------------------------------------------
in_path     <- file.path("data", "gapminder.csv")
out_path    <- file.path("data", "gapminder_clean.csv")
report_path <- file.path("data", "quality_report.txt")

# 리포트 출력을 콘솔과 파일에 동시에 남기기
report_lines <- character(0)
say <- function(...) {
  line <- paste0(...)
  cat(line, "\n")
  report_lines <<- c(report_lines, line)
}
rule <- function() say(strrep("-", 60))

# ---- 1. 로드 ------------------------------------------------------------
if (!file.exists(in_path)) stop("입력 파일이 없습니다: ", in_path)

df <- read.csv(in_path, stringsAsFactors = FALSE, encoding = "UTF-8")

say("Gapminder 데이터 품질 리포트")
say("생성 시각: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
say("입력 파일: ", in_path)
rule()

# ---- 2. 기본 구조 -------------------------------------------------------
say("[1] 기본 구조")
say("  행 수   : ", nrow(df))
say("  열 수   : ", ncol(df))
say("  컬럼명  : ", paste(names(df), collapse = ", "))
say("  컬럼타입: ", paste(sapply(df, class), collapse = ", "))
rule()

# ---- 3. 기대 스키마 검증 ------------------------------------------------
say("[2] 스키마 검증")
expected_cols <- c("country", "year", "pop", "continent", "lifeExp", "gdpPercap")
missing_cols  <- setdiff(expected_cols, names(df))
extra_cols    <- setdiff(names(df), expected_cols)
say("  기대 컬럼 존재 여부: ",
    if (length(missing_cols) == 0) "OK (모두 존재)" else paste("누락:", paste(missing_cols, collapse = ", ")))
if (length(extra_cols) > 0) say("  예상 외 컬럼: ", paste(extra_cols, collapse = ", "))
rule()

# ---- 4. 결측치(NA) 확인 -------------------------------------------------
say("[3] 결측치(NA) 개수 (컬럼별)")
na_counts <- sapply(df, function(x) sum(is.na(x)))
for (nm in names(na_counts)) say(sprintf("  %-10s : %d", nm, na_counts[[nm]]))
say("  총 결측치: ", sum(na_counts))
rule()

# ---- 5. 빈 문자열 / 공백 확인 -------------------------------------------
say("[4] 빈 문자열 확인 (문자형 컬럼)")
char_cols <- names(df)[sapply(df, is.character)]
if (length(char_cols) == 0) {
  say("  문자형 컬럼 없음")
} else {
  for (nm in char_cols) {
    blanks <- sum(trimws(df[[nm]]) == "", na.rm = TRUE)
    say(sprintf("  %-10s : 빈값 %d", nm, blanks))
  }
}
rule()

# ---- 6. 중복 행 확인 ----------------------------------------------------
say("[5] 중복 확인")
dup_full <- sum(duplicated(df))
say("  완전 중복 행: ", dup_full)
if (all(c("country", "year") %in% names(df))) {
  dup_key <- sum(duplicated(df[, c("country", "year")]))
  say("  (country, year) 키 중복: ", dup_key)
}
rule()

# ---- 7. 수치형 값 범위 / 이상치 -----------------------------------------
say("[6] 수치형 컬럼 요약 및 범위 점검")
num_cols <- names(df)[sapply(df, is.numeric)]
for (nm in num_cols) {
  v <- df[[nm]]
  say(sprintf("  %-10s : min=%.3f  median=%.3f  max=%.3f  mean=%.3f",
              nm, min(v, na.rm = TRUE), median(v, na.rm = TRUE),
              max(v, na.rm = TRUE), mean(v, na.rm = TRUE)))
}
say("")
say("  도메인 규칙 위반 점검:")
check_rule <- function(label, condition_bad) {
  n <- sum(condition_bad, na.rm = TRUE)
  say(sprintf("    %-28s : %s", label, if (n == 0) "OK" else paste0("위반 ", n, "건")))
}
if ("pop"       %in% names(df)) check_rule("pop > 0",            !(df$pop > 0))
if ("lifeExp"   %in% names(df)) check_rule("lifeExp 0~120",      !(df$lifeExp >= 0 & df$lifeExp <= 120))
if ("gdpPercap" %in% names(df)) check_rule("gdpPercap > 0",      !(df$gdpPercap > 0))
if ("year"      %in% names(df)) check_rule("year 1800~2100",     !(df$year >= 1800 & df$year <= 2100))
rule()

# ---- 8. 범주형 값 점검 --------------------------------------------------
say("[7] 범주형 컬럼 점검")
if ("continent" %in% names(df)) {
  tb <- sort(table(df$continent), decreasing = TRUE)
  say("  continent 분포:")
  for (nm in names(tb)) say(sprintf("    %-12s : %d", nm, tb[[nm]]))
}
if ("country" %in% names(df)) {
  say("  고유 country 수: ", length(unique(df$country)))
}
if ("year" %in% names(df)) {
  yrs <- sort(unique(df$year))
  say("  고유 year 수: ", length(yrs), "  (", min(yrs), " ~ ", max(yrs), ")")
}
rule()

# ---- 9. 패널 균형(Balanced panel) 점검 ----------------------------------
say("[8] 패널 균형 점검 (국가별 관측 연도 수)")
if (all(c("country", "year") %in% names(df))) {
  per_country <- tapply(df$year, df$country, function(x) length(unique(x)))
  mode_n <- as.integer(names(sort(table(per_country), decreasing = TRUE))[1])
  unbalanced <- per_country[per_country != mode_n]
  say("  표준 관측 연도 수(최빈값): ", mode_n)
  if (length(unbalanced) == 0) {
    say("  모든 국가가 동일한 연도 수를 가짐 (균형 패널 OK)")
  } else {
    say("  불균형 국가 ", length(unbalanced), "개:")
    for (nm in names(unbalanced)) say(sprintf("    %-25s : %d 년", nm, unbalanced[[nm]]))
  }
}
rule()

# ---- 10. 정제(clean) 작업 ----------------------------------------------
# 보수적 정제: 완전 중복 제거, 문자열 공백 정리, 행 정렬
say("[9] 정제 수행")
clean <- df

# 문자열 앞뒤 공백 제거
for (nm in char_cols) clean[[nm]] <- trimws(clean[[nm]])

# 완전 중복 행 제거
n_before <- nrow(clean)
clean <- clean[!duplicated(clean), ]
say("  완전 중복 제거: ", n_before - nrow(clean), "행")

# country, year 순으로 정렬
if (all(c("country", "year") %in% names(clean))) {
  clean <- clean[order(clean$country, clean$year), ]
}

write.csv(clean, out_path, row.names = FALSE, fileEncoding = "UTF-8")
say("  정제본 저장: ", out_path, "  (", nrow(clean), "행)")
rule()

# ---- 11. 종합 판정 ------------------------------------------------------
say("[10] 종합 판정")
issues <- 0
issues <- issues + sum(na_counts)
issues <- issues + dup_full
if ("pop"       %in% names(df)) issues <- issues + sum(!(df$pop > 0), na.rm = TRUE)
if ("gdpPercap" %in% names(df)) issues <- issues + sum(!(df$gdpPercap > 0), na.rm = TRUE)
if ("lifeExp"   %in% names(df)) issues <- issues + sum(!(df$lifeExp >= 0 & df$lifeExp <= 120), na.rm = TRUE)
if (issues == 0) {
  say("  결과: 통과 (PASS) — 결측/중복/도메인 위반 없음")
} else {
  say("  결과: 검토 필요 — 발견된 이슈 합계 ", issues, "건 (위 항목 참조)")
}
rule()

# ---- 12. 리포트 파일 저장 ----------------------------------------------
writeLines(report_lines, report_path)
cat("\n리포트 저장 완료:", report_path, "\n")
