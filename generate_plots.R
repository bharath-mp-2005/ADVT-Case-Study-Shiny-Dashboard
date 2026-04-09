# ============================================================
#  CSI 3005 – Generate Analysis Plots for README
#  Run this script ONCE to produce all images
#  Place master.csv in the same folder before running
# ============================================================

library(ggplot2)
library(dplyr)
library(tidyr)
library(RColorBrewer)
library(scales)

# ── Create images folder ─────────────────────────────────────
if (!dir.exists("images")) dir.create("images")

# ── Load & Clean ─────────────────────────────────────────────
df <- read.csv("master.csv", stringsAsFactors = FALSE)
colnames(df) <- c("country","year","sex","age","suicides_no","population",
                  "suicides_per_100k","country_year","hdi","gdp_year",
                  "gdp_per_capita","generation")
df$gdp_per_capita   <- as.numeric(gsub("[^0-9.]", "", df$gdp_per_capita))
df$suicides_no      <- as.numeric(df$suicides_no)
df$population       <- as.numeric(df$population)
df$suicides_per_100k <- as.numeric(df$suicides_per_100k)
df$year             <- as.integer(df$year)
df$hdi              <- as.numeric(df$hdi)
df <- df %>% filter(!is.na(suicides_no), !is.na(population))
age_order <- c("5-14 years","15-24 years","25-34 years",
               "35-54 years","55-74 years","75+ years")
df$age <- factor(df$age, levels = age_order)

# Common theme
theme_dash <- theme_minimal(base_size = 13) +
  theme(
    plot.title       = element_text(face = "bold", size = 15, color = "#1E3A8A", margin = margin(b=10)),
    plot.subtitle    = element_text(size = 11, color = "#555555", margin = margin(b=8)),
    plot.background  = element_rect(fill = "#F8F9FC", color = NA),
    panel.background = element_rect(fill = "#FFFFFF", color = NA),
    panel.grid.major = element_line(color = "#E5E7EB", linewidth = 0.5),
    panel.grid.minor = element_blank(),
    axis.title       = element_text(color = "#374151", size = 11),
    axis.text        = element_text(color = "#6B7280", size = 10),
    legend.background = element_rect(fill = "#F8F9FC", color = NA),
    legend.title     = element_text(face = "bold", size = 10),
    plot.caption     = element_text(color = "#9CA3AF", size = 9, hjust = 1),
    plot.margin      = margin(16, 16, 16, 16)
  )

# ── PLOT 1: Global Suicide Trend Over Time ───────────────────
cat("Generating plot 1: Global trend...\n")
p1 <- df %>%
  group_by(year) %>%
  summarise(
    total = sum(suicides_no),
    rate  = mean(suicides_per_100k)
  ) %>%
  ggplot(aes(x = year)) +
  geom_area(aes(y = total / 1000), fill = "#BFDBFE", alpha = 0.6) +
  geom_line(aes(y = total / 1000), color = "#1E3A8A", linewidth = 1.2) +
  geom_point(aes(y = total / 1000), color = "#1E3A8A", size = 2) +
  scale_x_continuous(breaks = seq(1985, 2016, 5)) +
  scale_y_continuous(labels = comma) +
  labs(
    title    = "Global Suicide Count Over Time (1985–2016)",
    subtitle = "Total suicides (thousands) across all countries",
    x = "Year", y = "Total Suicides (thousands)",
    
  ) + theme_dash

ggsave("images/plot1_global_trend.png", p1, width = 10, height = 5.5, dpi = 150)


# ── PLOT 2: Suicide Rate by Sex Over Time ────────────────────
cat("Generating plot 2: Sex trend...\n")
p2 <- df %>%
  group_by(year, sex) %>%
  summarise(rate = mean(suicides_per_100k), .groups = "drop") %>%
  ggplot(aes(x = year, y = rate, color = sex, fill = sex)) +
  geom_ribbon(aes(ymin = 0, ymax = rate), alpha = 0.15) +
  geom_line(linewidth = 1.3) +
  geom_point(size = 1.8) +
  scale_color_manual(values = c("male" = "#1E3A8A", "female" = "#DB2777")) +
  scale_fill_manual(values  = c("male" = "#1E3A8A", "female" = "#DB2777")) +
  scale_x_continuous(breaks = seq(1985, 2016, 5)) +
  labs(
    title    = "Suicide Rate by Sex Over Time",
    subtitle = "Average rate per 100k population — males consistently 3–4× higher",
    x = "Year", y = "Rate per 100k", color = "Sex", fill = "Sex",
    
  ) + theme_dash

ggsave("images/plot2_sex_trend.png", p2, width = 10, height = 5.5, dpi = 150)


# ── PLOT 3: Rate Distribution by Age Group (Box Plot) ────────
cat("Generating plot 3: Age box plot...\n")
p3 <- df %>%
  ggplot(aes(x = age, y = suicides_per_100k, fill = age)) +
  geom_boxplot(outlier.shape = 21, outlier.size = 1.5,
               outlier.color = "#9CA3AF", alpha = 0.85, linewidth = 0.5) +
  scale_fill_brewer(palette = "RdYlBu", direction = -1) +
  scale_y_continuous(limits = c(0, 120)) +
  labs(
    title    = "Suicide Rate Distribution by Age Group",
    subtitle = "75+ age group has the highest median and widest spread",
    x = "Age Group", y = "Rate per 100k",
    
  ) +
  theme_dash + theme(legend.position = "none")

ggsave("images/plot3_age_boxplot.png", p3, width = 10, height = 5.5, dpi = 150)


# ── PLOT 4: Top 15 Countries by Suicide Rate ─────────────────
cat("Generating plot 4: Top 15 countries...\n")
p4 <- df %>%
  group_by(country) %>%
  summarise(rate = mean(suicides_per_100k)) %>%
  slice_max(rate, n = 15) %>%
  ggplot(aes(x = rate, y = reorder(country, rate), fill = rate)) +
  geom_col(width = 0.7) +
  geom_text(aes(label = round(rate, 1)), hjust = -0.2, size = 3.5, color = "#374151") +
  scale_fill_gradient(low = "#FCA5A5", high = "#991B1B") +
  scale_x_continuous(expand = expansion(mult = c(0, 0.12))) +
  labs(
    title    = "Top 15 Countries by Average Suicide Rate",
    subtitle = "Average suicides per 100k population (1985–2016)",
    x = "Avg Rate per 100k", y = NULL, fill = "Rate",
    
  ) + theme_dash

ggsave("images/plot4_top_countries.png", p4, width = 10, height = 6, dpi = 150)


# ── PLOT 5: Heatmap – Age Group × Sex ────────────────────────
cat("Generating plot 5: Heatmap...\n")
p5 <- df %>%
  group_by(age, sex) %>%
  summarise(rate = mean(suicides_per_100k), .groups = "drop") %>%
  ggplot(aes(x = sex, y = age, fill = rate)) +
  geom_tile(color = "white", linewidth = 1.2) +
  geom_text(aes(label = round(rate, 1)), size = 5, fontface = "bold", color = "white") +
  scale_fill_gradient(low = "#FEF9C3", high = "#7F1D1D") +
  labs(
    title    = "Suicide Rate Heatmap: Age Group × Sex",
    subtitle = "Older males show significantly elevated rates",
    x = "Sex", y = "Age Group", fill = "Rate/100k",
    
  ) + theme_dash +
  theme(panel.grid = element_blank())

ggsave("images/plot5_heatmap.png", p5, width = 7, height = 5.5, dpi = 150)


# ── PLOT 6: Suicides by Generation ───────────────────────────
cat("Generating plot 6: Generation bar...\n")
gen_order <- df %>%
  group_by(generation) %>%
  summarise(rate = mean(suicides_per_100k)) %>%
  arrange(rate) %>% pull(generation)

p6 <- df %>%
  group_by(generation) %>%
  summarise(rate = mean(suicides_per_100k)) %>%
  mutate(generation = factor(generation, levels = gen_order)) %>%
  ggplot(aes(x = rate, y = generation, fill = rate)) +
  geom_col(width = 0.65) +
  geom_text(aes(label = round(rate, 1)), hjust = -0.2, size = 4, color = "#374151") +
  scale_fill_gradient(low = "#BAE6FD", high = "#1E3A8A") +
  scale_x_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(
    title    = "Average Suicide Rate by Generation",
    subtitle = "G.I. Generation and Silent Generation show the highest rates",
    x = "Avg Rate per 100k", y = NULL, fill = "Rate",
    
  ) + theme_dash

ggsave("images/plot6_generation.png", p6, width = 10, height = 5, dpi = 150)


# ── PLOT 7: GDP per Capita vs Suicide Rate ───────────────────
cat("Generating plot 7: GDP scatter...\n")
p7 <- df %>%
  filter(!is.na(gdp_per_capita), gdp_per_capita > 0) %>%
  group_by(country, year) %>%
  summarise(rate = mean(suicides_per_100k),
            gdp  = mean(gdp_per_capita), .groups = "drop") %>%
  ggplot(aes(x = gdp, y = rate)) +
  geom_point(alpha = 0.35, size = 2, color = "#1E3A8A") +
  geom_smooth(method = "loess", se = TRUE, color = "#DB2777",
              fill = "#FBCFE8", linewidth = 1.2) +
  scale_x_log10(labels = dollar_format(prefix = "$")) +
  labs(
    title    = "GDP per Capita vs Suicide Rate",
    subtitle = "Log-scaled x-axis; LOESS trend line with 95% CI",
    x = "GDP per Capita (log scale)", y = "Rate per 100k",
    
  ) + theme_dash

ggsave("images/plot7_gdp_scatter.png", p7, width = 10, height = 5.5, dpi = 150)


# ── PLOT 8: Suicide Rate by Age Group Over Time ──────────────
cat("Generating plot 8: Age trend over time...\n")
p8 <- df %>%
  group_by(year, age) %>%
  summarise(rate = mean(suicides_per_100k), .groups = "drop") %>%
  ggplot(aes(x = year, y = rate, color = age)) +
  geom_line(linewidth = 1.1) +
  scale_color_brewer(palette = "RdYlBu", direction = -1) +
  scale_x_continuous(breaks = seq(1985, 2016, 5)) +
  labs(
    title    = "Suicide Rate by Age Group Over Time",
    subtitle = "75+ group dominates; younger cohorts remain relatively stable",
    x = "Year", y = "Rate per 100k", color = "Age Group",
    
  ) + theme_dash

ggsave("images/plot8_age_trend.png", p8, width = 10, height = 5.5, dpi = 150)


cat("\n✅ All 8 plots saved to the images/ folder!\n")
cat("Now run: git add images/ && git commit -m 'add analysis plots' && git push\n")