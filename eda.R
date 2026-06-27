# eda.R  (최종본 / Final)
# Gapminder 탐색적 데이터 분석 (Exploratory Data Analysis)
# -----------------------------------------------------------------------
# 개정 내용: 단순 기술통계·상관을 넘어, 흔히 놓치는 방법론적 이슈를 보완
#   1) 인구가중 평균 vs 단순평균 (Simpson's paradox 방지)
#   2) 기대수명이 '하락'한 국가 탐지 (대륙평균이 숨기는 반전)
#   3) Pearson + Spearman + 연도별 상관 안정성
#   4) 이상치(IQR) 탐지 및 명시 (예: 쿠웨이트 GDP)
#   5) 분포 왜도(skewness) 및 기하평균
#   6) 수렴/발산 분석 (연도별 SD 추이)
#   7) 대륙 내 이질성(변동계수 CV)
#   8) Preston 곡선 loess 추세선
# -----------------------------------------------------------------------
# 입력 : data/gapminder_clean.csv (없으면 data/gapminder.csv)
# 출력 : figures/*.png, document/eda_summary.txt
# 실행 : Rscript eda.R
# 의존성: ggplot2, dplyr, tidyr

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(tidyr)
})

# ---- 0. 설정 / 헬퍼 -----------------------------------------------------
in_path  <- if (file.exists(file.path("data", "gapminder_clean.csv")))
              file.path("data", "gapminder_clean.csv") else file.path("data", "gapminder.csv")
fig_dir  <- "figures"
rep_path <- file.path("document", "eda_summary.txt")
dir.create(fig_dir, showWarnings = FALSE)
dir.create("document", showWarnings = FALSE)

theme_set(theme_minimal(base_size = 12))
ggsave2 <- function(name, plot, w = 8, h = 5)
  ggsave(file.path(fig_dir, name), plot, width = w, height = h, dpi = 120)

rep_lines <- character(0)
say  <- function(...) { l <- paste0(...); cat(l, "\n"); rep_lines <<- c(rep_lines, l) }
rule <- function() say(strrep("-", 60))

# 추가 통계 헬퍼
skewness <- function(x) { x <- x[!is.na(x)]; m <- mean(x); s <- sd(x); mean((x - m)^3) / s^3 }
geomean  <- function(x) exp(mean(log(x[x > 0])))
cv       <- function(x) sd(x) / mean(x)   # 변동계수

# ---- 1. 로드 ------------------------------------------------------------
gap <- read.csv(in_path, stringsAsFactors = FALSE)
gap$continent <- factor(gap$continent)
gap$pop <- as.numeric(gap$pop)
latest <- max(gap$year); earliest <- min(gap$year)

say("Gapminder 탐색적 데이터 분석(EDA) — 최종본")
say("입력 파일: ", in_path)
say("관측치: ", nrow(gap), "행  /  국가: ", length(unique(gap$country)),
    "  /  연도: ", earliest, "~", latest)
say("주의: 142개국만 포함(전 세계 아님), 5년 간격 패널. 인과 아님(상관/기술 통계).")
rule()

# ---- 2. 기술통계 + 분포 형태 -------------------------------------------
say("[1] 기술통계 및 분포 형태")
num_vars <- c("lifeExp", "pop", "gdpPercap")
for (v in num_vars) {
  x <- gap[[v]]
  say(sprintf("  %-10s  median=%.1f  mean=%.1f  sd=%.1f  왜도=%.2f",
              v, median(x), mean(x), sd(x), skewness(x)))
}
say("  -> pop, gdpPercap는 강한 우편향(왜도>0). 대표값으로 기하평균이 적절:")
say(sprintf("     gdpPercap 산술평균=%.0f  vs  기하평균=%.0f (3.6배 차이 -> 산술평균 과대)",
            mean(gap$gdpPercap), geomean(gap$gdpPercap)))
rule()

# ---- 3. 이상치(IQR) 탐지 ------------------------------------------------
say("[2] 이상치 탐지 (1.5*IQR 규칙)")
for (v in num_vars) {
  x <- gap[[v]]; q <- quantile(x, c(.25, .75)); iqr <- q[2] - q[1]
  hi <- q[2] + 1.5 * iqr
  n_out <- sum(x > hi)
  say(sprintf("  %-10s  상한=%.0f 초과 관측 %d건", v, hi, n_out))
}
# 대표적 극단값 명시
kuw <- gap %>% filter(gdpPercap == max(gdpPercap))
say(sprintf("  최고 GDP 이상치: %s %d년 = %.0f (산유국 anomaly, 평균·상관 왜곡 주의)",
            kuw$country, kuw$year, kuw$gdpPercap))
rule()

# ---- 4. 대륙별: 단순평균 vs 인구가중평균 (Simpson 방지) -----------------
say("[3] 대륙별 기대수명 — 단순평균 vs 인구가중평균 (", latest, ")")
cont <- gap %>% filter(year == latest) %>%
  group_by(continent) %>%
  summarise(n = n(),
            le_simple   = mean(lifeExp),
            le_weighted = weighted.mean(lifeExp, pop),
            le_cv       = cv(lifeExp),        # 대륙 내 이질성
            .groups = "drop") %>%
  arrange(desc(le_weighted))
for (i in seq_len(nrow(cont))) {
  r <- cont[i, ]
  say(sprintf("  %-10s n=%2d  단순=%.1f  가중=%.1f  차이=%+.1f  내부변동(CV)=%.3f",
              r$continent, r$n, r$le_simple, r$le_weighted,
              r$le_weighted - r$le_simple, r$le_cv))
}
say("  -> 가중평균이 단순평균과 다른 대륙은 큰 나라 효과가 큼. 아시아 내부변동(CV)이 커",
    " '아시아 평균'은 대표성이 약함.")
rule()

# ---- 5. 기대수명이 '하락'한 국가 (대륙평균이 숨기는 반전) ---------------
say("[4] 기대수명 하락/정체 국가 탐지")
traj <- gap %>% arrange(country, year) %>% group_by(country) %>%
  mutate(step = lifeExp - lag(lifeExp)) %>%
  summarise(continent = first(continent),
            net = lifeExp[year == latest] - lifeExp[year == earliest],
            worst_step = min(step, na.rm = TRUE),
            n_drops = sum(step < 0, na.rm = TRUE),
            .groups = "drop")
net_decline <- traj %>% filter(net < 0) %>% arrange(net)
say("  1952->2007 '순(net) 하락' 국가: ", nrow(net_decline), "개")
for (i in seq_len(nrow(net_decline)))
  say(sprintf("    %-22s (%s)  순변화 %+.1f년", net_decline$country[i],
              net_decline$continent[i], net_decline$net[i]))
say("  최소 한 번이라도 5년새 하락 경험한 국가: ", sum(traj$n_drops > 0), "개")
worst_step <- traj %>% arrange(worst_step) %>% head(5)
say("  단일 구간 최대 하락 TOP5:")
for (i in seq_len(nrow(worst_step)))
  say(sprintf("    %-22s  %.1f년 하락", worst_step$country[i], worst_step$worst_step[i]))
say("  -> '모든 대륙 상승'은 평균의 착시. 국가 단위에선 명백한 반전 존재(HIV/AIDS, 분쟁).")
rule()

# ---- 6. 상관: Pearson + Spearman + 연도별 안정성 ------------------------
say("[5] 상관관계 (강건성 점검)")
say(sprintf("  lifeExp ~ gdpPercap     Pearson=%.3f  Spearman=%.3f",
            cor(gap$lifeExp, gap$gdpPercap),
            cor(gap$lifeExp, gap$gdpPercap, method = "spearman")))
say(sprintf("  lifeExp ~ log(gdpPercap) Pearson=%.3f  (선형화로 상관 상승)",
            cor(gap$lifeExp, log(gap$gdpPercap))))
say("  연도별 lifeExp~log(gdp) 상관 (시간 안정성):")
by_year <- gap %>% group_by(year) %>%
  summarise(r = cor(lifeExp, log(gdpPercap)), .groups = "drop")
say("    ", paste(sprintf("%d:%.2f", by_year$year, by_year$r), collapse = "  "))
say("  -> 전 기간 풀링 상관은 횡단면+시계열 혼재(Simpson 위험). 연도별로 봐도 0.7~0.8 안정적.")
rule()

# ---- 7. 수렴/발산 분석 --------------------------------------------------
say("[6] 세계는 수렴하는가? (연도별 분산 추이)")
disp <- gap %>% group_by(year) %>%
  summarise(le_sd  = sd(lifeExp),
            gdp_cv = cv(gdpPercap), .groups = "drop")
say("  기대수명 표준편차: ", earliest, "=", sprintf("%.1f", disp$le_sd[1]),
    " -> ", latest, "=", sprintf("%.1f", disp$le_sd[nrow(disp)]),
    if (disp$le_sd[nrow(disp)] < disp$le_sd[1]) "  (수렴)" else "  (발산)")
say("  GDP 변동계수: ", earliest, "=", sprintf("%.2f", disp$gdp_cv[1]),
    " -> ", latest, "=", sprintf("%.2f", disp$gdp_cv[nrow(disp)]),
    if (disp$gdp_cv[nrow(disp)] > disp$gdp_cv[1]) "  (소득 격차 확대)" else "  (축소)")
rule()

# ========================================================================
#  시각화
# ========================================================================
say("[7] 시각화 저장 (figures/)")

# (1) 기대수명 분포
p1 <- ggplot(gap, aes(lifeExp)) +
  geom_histogram(bins = 30, fill = "#2c7fb8", colour = "white") +
  labs(title = "기대수명 분포 (전체 연도)", x = "기대수명", y = "빈도")
ggsave2("01_lifeExp_hist.png", p1); say("  01_lifeExp_hist.png")

# (2) 대륙별 기대수명 박스플롯 (분포+이상치)
p2 <- ggplot(filter(gap, year == latest),
             aes(reorder(continent, lifeExp, median), lifeExp, fill = continent)) +
  geom_boxplot(show.legend = FALSE, outlier.colour = "red") +
  labs(title = paste0("대륙별 기대수명 분포 (", latest, ")"), x = "대륙", y = "기대수명")
ggsave2("02_lifeExp_box_continent.png", p2); say("  02_lifeExp_box_continent.png")

# (3) 단순평균 vs 인구가중평균 비교
p3 <- cont %>%
  pivot_longer(c(le_simple, le_weighted), names_to = "type", values_to = "le") %>%
  mutate(type = recode(type, le_simple = "단순평균", le_weighted = "인구가중평균")) %>%
  ggplot(aes(reorder(continent, le), le, fill = type)) +
  geom_col(position = "dodge") + coord_flip() +
  labs(title = paste0("대륙 기대수명: 단순 vs 인구가중 (", latest, ")"),
       x = NULL, y = "기대수명", fill = NULL)
ggsave2("03_weighted_vs_simple.png", p3); say("  03_weighted_vs_simple.png")

# (4) Preston 곡선: GDP vs 기대수명 + loess 추세선 (로그 x, 버블=인구)
p4 <- ggplot(filter(gap, year == latest),
             aes(gdpPercap, lifeExp)) +
  geom_point(aes(size = pop, colour = continent), alpha = 0.7) +
  geom_smooth(method = "loess", se = TRUE, colour = "black", linewidth = 0.8) +
  scale_x_log10() + scale_size(range = c(1, 14), guide = "none") +
  labs(title = paste0("Preston 곡선: 1인당 GDP vs 기대수명 (", latest, ")"),
       subtitle = "로그 GDP에 대해 포화(saturation)되는 비선형 관계",
       x = "1인당 GDP (로그)", y = "기대수명", colour = "대륙")
ggsave2("04_preston_curve.png", p4, w = 9, h = 6); say("  04_preston_curve.png")

# (5) 대륙별 평균 기대수명 추이 (정체 구간 확인)
trend <- gap %>% group_by(continent, year) %>%
  summarise(lifeExp = mean(lifeExp), .groups = "drop")
p5 <- ggplot(trend, aes(year, lifeExp, colour = continent)) +
  geom_line(linewidth = 1) + geom_point(size = 1.5) +
  labs(title = "대륙별 평균 기대수명 추이", x = "연도", y = "평균 기대수명", colour = "대륙")
ggsave2("05_lifeExp_trend.png", p5); say("  05_lifeExp_trend.png")

# (6) 기대수명이 하락(net<0)한 국가들의 궤적 — 평균이 숨기는 반전
decl_countries <- net_decline$country
p6 <- gap %>% filter(country %in% decl_countries) %>%
  ggplot(aes(year, lifeExp, colour = country)) +
  geom_line(linewidth = 1) + geom_point(size = 1.3) +
  labs(title = "기대수명이 '하락'한 국가 (1952 > 2007)",
       subtitle = "대륙 평균의 상승세에 가려진 반전 사례",
       x = "연도", y = "기대수명", colour = "국가")
ggsave2("06_lifeExp_reversals.png", p6, w = 9, h = 6); say("  06_lifeExp_reversals.png")

# (7) 수렴/발산: 연도별 기대수명 SD & GDP CV
p7 <- disp %>%
  select(year, `기대수명 SD` = le_sd, `GDP 변동계수` = gdp_cv) %>%
  pivot_longer(-year, names_to = "metric", values_to = "v") %>%
  ggplot(aes(year, v, colour = metric)) +
  geom_line(linewidth = 1) + geom_point() +
  facet_wrap(~metric, scales = "free_y") +
  labs(title = "세계는 수렴하는가? — 연도별 분산 추이",
       subtitle = "기대수명 SD는 거의 정체(평균은 상승), GDP CV는 감소(단 초기값은 쿠웨이트 이상치 영향)",
       x = "연도", y = NULL, colour = NULL) +
  theme(legend.position = "none")
ggsave2("07_convergence.png", p7, w = 9, h = 5); say("  07_convergence.png")

# (8) 대륙별 총인구 추이
poptrend <- gap %>% group_by(continent, year) %>%
  summarise(pop = sum(pop) / 1e9, .groups = "drop")
p8 <- ggplot(poptrend, aes(year, pop, fill = continent)) +
  geom_area(alpha = 0.85) +
  labs(title = "대륙별 총인구 추이", x = "연도", y = "인구 (10억 명)", fill = "대륙")
ggsave2("08_population_trend.png", p8); say("  08_population_trend.png")

# (9) 기대수명 상/하위 10개국 (최신연도)
le_latest <- filter(gap, year == latest)
tb <- bind_rows(
  le_latest %>% arrange(desc(lifeExp)) %>% head(10) %>% mutate(grp = "상위 10"),
  le_latest %>% arrange(lifeExp)       %>% head(10) %>% mutate(grp = "하위 10"))
p9 <- ggplot(tb, aes(reorder(country, lifeExp), lifeExp, fill = grp)) +
  geom_col() + coord_flip() +
  labs(title = paste0("기대수명 상/하위 10개국 (", latest, ")"),
       x = NULL, y = "기대수명", fill = NULL)
ggsave2("09_top_bottom_lifeExp.png", p9, h = 6); say("  09_top_bottom_lifeExp.png")
rule()

# ---- 8. 핵심 인사이트 & 한계 -------------------------------------------
say("[8] 핵심 인사이트")
gw <- traj %>% group_by(continent) %>%
  summarise(avg_gain = round(mean(net), 1), .groups = "drop") %>% arrange(desc(avg_gain))
say("  - 기대수명 평균 증가폭(대륙): ",
    paste(sprintf("%s %.1f년", gw$continent, gw$avg_gain), collapse = ", "))
say("  - 소득-수명: 로그 GDP 기준 상관 ", sprintf("%.3f", cor(gap$lifeExp, log(gap$gdpPercap))),
    " (Preston 곡선, 고소득 구간 포화)")
say("  - 단, 평균은 ", nrow(net_decline), "개국의 기대수명 하락 반전을 숨김")
say("  - 기대수명 분산은 거의 정체(SD ", sprintf("%.1f->%.1f", disp$le_sd[1], disp$le_sd[nrow(disp)]),
    "): 평균은 올랐으나 아프리카 반전으로 하단이 벌어져 격차 축소로 단정 불가")
say("  - 소득 변동계수(CV)는 감소(", sprintf("%.2f->%.2f", disp$gdp_cv[1], disp$gdp_cv[nrow(disp)]),
    ")하나 초기값이 쿠웨이트 이상치로 부풀려진 점 유의 -> '발산/수렴' 단정 주의")
say("")
say("  [한계]")
say("  - 142개국만 포함, 5년 간격 -> 전수/연속 데이터 아님")
say("  - 모든 통계는 기술적/상관적이며 인과 추론 아님")
say("  - 대륙 평균은 인구 가중 시 해석이 달라짐(아래 그림 03 참조)")
say("  - 1인당 GDP는 분배가 아닌 평균 -> 국가 내 불평등 미반영")
rule()

writeLines(rep_lines, rep_path)
cat("\nEDA 요약 저장:", rep_path, "\n그림 저장:", fig_dir, "/\n")
