# eda.R
# Gapminder 탐색적 데이터 분석 (Exploratory Data Analysis)
# 입력 : data/gapminder_clean.csv  (없으면 data/gapminder.csv)
# 출력 : figures/*.png            (시각화 8종)
#        document/eda_summary.txt (요약 통계 리포트)
# 실행 : Rscript eda.R
# 의존성: ggplot2, dplyr, tidyr

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(tidyr)
})

# ---- 0. 설정 ------------------------------------------------------------
in_path  <- if (file.exists(file.path("data", "gapminder_clean.csv")))
              file.path("data", "gapminder_clean.csv") else file.path("data", "gapminder.csv")
fig_dir  <- "figures"
rep_path <- file.path("document", "eda_summary.txt")
dir.create(fig_dir, showWarnings = FALSE)
dir.create("document", showWarnings = FALSE)

theme_set(theme_minimal(base_size = 12))
ggsave2 <- function(name, plot, w = 8, h = 5)
  ggsave(file.path(fig_dir, name), plot, width = w, height = h, dpi = 120)

# 리포트 누적 출력
rep_lines <- character(0)
say <- function(...) { l <- paste0(...); cat(l, "\n"); rep_lines <<- c(rep_lines, l) }
rule <- function() say(strrep("-", 60))

# ---- 1. 로드 ------------------------------------------------------------
gap <- read.csv(in_path, stringsAsFactors = FALSE)
gap$continent <- factor(gap$continent)

say("Gapminder 탐색적 데이터 분석(EDA) 요약")
say("입력 파일: ", in_path)
say("관측치: ", nrow(gap), "행  /  국가: ", length(unique(gap$country)),
    "  /  연도: ", min(gap$year), "~", max(gap$year))
rule()

# ---- 2. 전체 기술통계 ---------------------------------------------------
say("[1] 주요 변수 기술통계")
num_vars <- c("lifeExp", "pop", "gdpPercap")
for (v in num_vars) {
  x <- gap[[v]]
  say(sprintf("  %-10s  min=%.1f  Q1=%.1f  median=%.1f  mean=%.1f  Q3=%.1f  max=%.1f  sd=%.1f",
              v, min(x), quantile(x, .25), median(x), mean(x),
              quantile(x, .75), max(x), sd(x)))
}
rule()

# ---- 3. 대륙별 요약 (최신 연도 2007) ------------------------------------
latest <- max(gap$year)
say("[2] 대륙별 요약 (", latest, "년 기준)")
cont_summary <- gap %>%
  filter(year == latest) %>%
  group_by(continent) %>%
  summarise(
    n_country   = n(),
    lifeExp_avg = round(mean(lifeExp), 1),
    gdp_avg     = round(mean(gdpPercap), 0),
    pop_total   = sum(as.numeric(pop)),
    .groups = "drop"
  ) %>% arrange(desc(lifeExp_avg))
for (i in seq_len(nrow(cont_summary))) {
  r <- cont_summary[i, ]
  say(sprintf("  %-10s  국가수=%2d  기대수명=%.1f  평균GDP=%-8.0f  총인구=%.0f",
              r$continent, r$n_country, r$lifeExp_avg, r$gdp_avg, r$pop_total))
}
rule()

# ---- 4. 상관관계 --------------------------------------------------------
say("[3] 변수 간 상관계수 (Pearson)")
cor_m <- cor(gap[, num_vars])
say("              lifeExp    pop   gdpPercap")
for (rn in rownames(cor_m))
  say(sprintf("  %-10s %7.3f %7.3f %7.3f", rn, cor_m[rn, 1], cor_m[rn, 2], cor_m[rn, 3]))
say("  주: gdpPercap는 로그변환 시 lifeExp와 상관 더 강해짐 -> ",
    sprintf("%.3f", cor(log(gap$gdpPercap), gap$lifeExp)))
rule()

# ---- 5. 시각화 ----------------------------------------------------------
say("[4] 시각화 저장 (figures/)")

# (1) 기대수명 분포
p1 <- ggplot(gap, aes(lifeExp)) +
  geom_histogram(bins = 30, fill = "#2c7fb8", colour = "white") +
  labs(title = "기대수명 분포 (전체 연도)", x = "기대수명", y = "빈도")
ggsave2("01_lifeExp_hist.png", p1); say("  01_lifeExp_hist.png")

# (2) 대륙별 기대수명 박스플롯 (최신연도)
p2 <- ggplot(filter(gap, year == latest), aes(reorder(continent, lifeExp, median), lifeExp, fill = continent)) +
  geom_boxplot(show.legend = FALSE) +
  labs(title = paste0("대륙별 기대수명 (", latest, ")"), x = "대륙", y = "기대수명")
ggsave2("02_lifeExp_box_continent.png", p2); say("  02_lifeExp_box_continent.png")

# (3) 연도별 평균 기대수명 추이 (대륙별)
trend <- gap %>% group_by(continent, year) %>% summarise(lifeExp = mean(lifeExp), .groups = "drop")
p3 <- ggplot(trend, aes(year, lifeExp, colour = continent)) +
  geom_line(linewidth = 1) + geom_point(size = 1.5) +
  labs(title = "대륙별 평균 기대수명 추이", x = "연도", y = "평균 기대수명", colour = "대륙")
ggsave2("03_lifeExp_trend.png", p3); say("  03_lifeExp_trend.png")

# (4) GDP vs 기대수명 산점도 (최신연도, 로그 x, 버블=인구)
p4 <- ggplot(filter(gap, year == latest),
             aes(gdpPercap, lifeExp, size = pop, colour = continent)) +
  geom_point(alpha = 0.7) +
  scale_x_log10() + scale_size(range = c(1, 14), guide = "none") +
  labs(title = paste0("1인당 GDP vs 기대수명 (", latest, ")"),
       x = "1인당 GDP (로그 스케일)", y = "기대수명", colour = "대륙")
ggsave2("04_gdp_vs_lifeExp.png", p4, w = 9, h = 6); say("  04_gdp_vs_lifeExp.png")

# (5) 대륙별 총인구 추이
poptrend <- gap %>% group_by(continent, year) %>%
  summarise(pop = sum(as.numeric(pop)) / 1e9, .groups = "drop")
p5 <- ggplot(poptrend, aes(year, pop, fill = continent)) +
  geom_area(alpha = 0.85) +
  labs(title = "대륙별 총인구 추이", x = "연도", y = "인구 (10억 명)", fill = "대륙")
ggsave2("05_population_trend.png", p5); say("  05_population_trend.png")

# (6) GDP 분포 (로그)
p6 <- ggplot(gap, aes(gdpPercap, fill = continent)) +
  geom_density(alpha = 0.4) + scale_x_log10() +
  labs(title = "대륙별 1인당 GDP 분포 (로그)", x = "1인당 GDP (로그)", y = "밀도", fill = "대륙")
ggsave2("06_gdp_density.png", p6); say("  06_gdp_density.png")

# (7) 기대수명 상위/하위 10개국 (최신연도)
le_latest <- filter(gap, year == latest)
top10 <- le_latest %>% arrange(desc(lifeExp)) %>% head(10) %>% mutate(grp = "상위 10")
bot10 <- le_latest %>% arrange(lifeExp)       %>% head(10) %>% mutate(grp = "하위 10")
tb <- bind_rows(top10, bot10)
p7 <- ggplot(tb, aes(reorder(country, lifeExp), lifeExp, fill = grp)) +
  geom_col(show.legend = TRUE) + coord_flip() +
  labs(title = paste0("기대수명 상/하위 10개국 (", latest, ")"),
       x = NULL, y = "기대수명", fill = NULL)
ggsave2("07_top_bottom_lifeExp.png", p7, h = 6); say("  07_top_bottom_lifeExp.png")

# (8) 기대수명 증가폭 (1952 -> 2007) 대륙별
growth <- gap %>%
  filter(year %in% c(min(year), max(year))) %>%
  select(country, continent, year, lifeExp) %>%
  pivot_wider(names_from = year, values_from = lifeExp) %>%
  mutate(gain = .data[[as.character(max(gap$year))]] - .data[[as.character(min(gap$year))]])
p8 <- ggplot(growth, aes(reorder(continent, gain, median), gain, fill = continent)) +
  geom_boxplot(show.legend = FALSE) +
  labs(title = paste0("기대수명 증가폭 (", min(gap$year), "→", max(gap$year), ")"),
       x = "대륙", y = "기대수명 증가 (년)")
ggsave2("08_lifeExp_gain.png", p8); say("  08_lifeExp_gain.png")
rule()

# ---- 6. 핵심 인사이트 ---------------------------------------------------
say("[5] 핵심 인사이트")
gw <- growth %>% group_by(continent) %>% summarise(avg_gain = round(mean(gain), 1), .groups = "drop") %>% arrange(desc(avg_gain))
say("  - 1952~2007 기대수명 평균 증가폭(대륙): ",
    paste(sprintf("%s %.1f년", gw$continent, gw$avg_gain), collapse = ", "))
say("  - 1인당 GDP와 기대수명: 양의 관계, 로그 GDP 기준 상관 ",
    sprintf("%.3f", cor(log(gap$gdpPercap), gap$lifeExp)), " (강함)")
best  <- cont_summary %>% slice_max(lifeExp_avg, n = 1)
worst <- cont_summary %>% slice_min(lifeExp_avg, n = 1)
say(sprintf("  - %d년 기대수명 최고 대륙: %s (%.1f), 최저 대륙: %s (%.1f)",
            latest, best$continent, best$lifeExp_avg, worst$continent, worst$lifeExp_avg))
rule()

writeLines(rep_lines, rep_path)
cat("\nEDA 요약 저장:", rep_path, "\n")
cat("그림 저장 위치:", fig_dir, "/\n")
