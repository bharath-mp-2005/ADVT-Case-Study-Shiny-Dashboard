# ============================================================
#  Suicide Statistics Dashboard — Shiny App
#  Course: CSI 3005 | Advanced Data Visualization Techniques
#  Student: Bharath | 23MID0014
# ============================================================

library(shiny)
library(shinydashboard)
library(ggplot2)
library(dplyr)
library(plotly)
library(DT)
library(scales)

# ── Load & Clean Data ────────────────────────────────────────
df <- read.csv("master.csv", stringsAsFactors = FALSE)

# Rename messy column names
colnames(df) <- c("country", "year", "sex", "age", "suicides_no",
                  "population", "suicides_per_100k", "country_year",
                  "hdi", "gdp_year", "gdp_per_capita", "generation")

# Clean GDP column (remove commas if any)
df$gdp_year       <- as.numeric(gsub("[^0-9]", "", df$gdp_year))
df$gdp_per_capita <- as.numeric(df$gdp_per_capita)
df$suicides_no    <- as.numeric(df$suicides_no)
df$population     <- as.numeric(df$population)
df$year           <- as.integer(df$year)

# Drop rows with NA in key columns
df <- df %>% filter(!is.na(suicides_no), !is.na(population))

# Age factor ordering
age_order <- c("5-14 years","15-24 years","25-34 years",
               "35-54 years","55-74 years","75+ years")
df$age <- factor(df$age, levels = age_order)

# ── UI ───────────────────────────────────────────────────────
ui <- dashboardPage(
  skin = "blue",
  
  dashboardHeader(title = "Global Suicide Statistics"),
  
  dashboardSidebar(
    sidebarMenu(
      menuItem("Overview",        tabName = "overview",   icon = icon("globe")),
      menuItem("Time-Series",     tabName = "timeseries", icon = icon("chart-line")),
      menuItem("Category Analysis",tabName = "category",  icon = icon("chart-bar")),
      menuItem("Correlations",    tabName = "correlation",icon = icon("project-diagram")),
      menuItem("Data Table",      tabName = "datatable",  icon = icon("table"))
    ),
    
    hr(),
    h5("  Filters", style = "color:#ccc; padding-left:10px;"),
    
    # Year slider
    sliderInput("year_range", "Year Range:",
                min = min(df$year), max = max(df$year),
                value = c(min(df$year), max(df$year)),
                sep = "", step = 1),
    
    # Sex filter
    checkboxGroupInput("sex_filter", "Sex:",
                       choices = unique(df$sex),
                       selected = unique(df$sex)),
    
    # Age filter
    checkboxGroupInput("age_filter", "Age Group:",
                       choices = levels(df$age),
                       selected = levels(df$age)),
    
    # Region / Country filter (top 20 by data volume)
    selectInput("country_filter", "Country (top 20):",
                choices = c("All", df %>%
                              count(country, sort = TRUE) %>%
                              slice_head(n = 20) %>%
                              pull(country)),
                selected = "All")
  ),
  
  dashboardBody(
    tabItems(
      
      # ── TAB 1: Overview KPIs ─────────────────────────────
      tabItem(tabName = "overview",
              fluidRow(
                valueBoxOutput("kpi_total_suicides", width = 3),
                valueBoxOutput("kpi_avg_rate",        width = 3),
                valueBoxOutput("kpi_peak_year",        width = 3),
                valueBoxOutput("kpi_countries",        width = 3)
              ),
              fluidRow(
                box(title = "Suicides per 100k by Generation",
                    plotlyOutput("gen_bar"), width = 6, solidHeader = TRUE, status = "primary"),
                box(title = "Male vs Female Split",
                    plotlyOutput("sex_pie"),  width = 6, solidHeader = TRUE, status = "primary")
              ),
              fluidRow(
                box(title = "Rate Distribution by Age Group",
                    plotlyOutput("age_box"),  width = 12, solidHeader = TRUE, status = "info")
              )
      ),
      
      # ── TAB 2: Time-Series ───────────────────────────────
      tabItem(tabName = "timeseries",
              fluidRow(
                box(title = "Global Suicides Over Time",
                    plotlyOutput("ts_global"), width = 12, solidHeader = TRUE, status = "primary")
              ),
              fluidRow(
                box(title = "Rate Trend by Sex",
                    plotlyOutput("ts_sex"),   width = 6, solidHeader = TRUE, status = "info"),
                box(title = "Rate Trend by Age Group",
                    plotlyOutput("ts_age"),   width = 6, solidHeader = TRUE, status = "info")
              )
      ),
      
      # ── TAB 3: Category Analysis ─────────────────────────
      tabItem(tabName = "category",
              fluidRow(
                box(title = "Top 15 Countries by Suicide Rate",
                    plotlyOutput("country_bar"), width = 12, solidHeader = TRUE, status = "primary")
              ),
              fluidRow(
                box(title = "Suicides by Age & Sex (Heatmap)",
                    plotlyOutput("age_sex_heat"), width = 6, solidHeader = TRUE, status = "warning"),
                box(title = "Generation-wise Rate",
                    plotlyOutput("gen_line"),    width = 6, solidHeader = TRUE, status = "warning")
              )
      ),
      
      # ── TAB 4: Correlations ──────────────────────────────
      tabItem(tabName = "correlation",
              fluidRow(
                box(title = "GDP per Capita vs Suicide Rate",
                    plotlyOutput("gdp_scatter"), width = 6, solidHeader = TRUE, status = "success"),
                box(title = "HDI vs Suicide Rate",
                    plotlyOutput("hdi_scatter"), width = 6, solidHeader = TRUE, status = "success")
              ),
              fluidRow(
                box(title = "Population vs Suicides (log scale)",
                    plotlyOutput("pop_scatter"), width = 12, solidHeader = TRUE, status = "info")
              )
      ),
      
      # ── TAB 5: Data Table ────────────────────────────────
      tabItem(tabName = "datatable",
              fluidRow(
                box(title = "Filtered Dataset",
                    DTOutput("raw_table"), width = 12, solidHeader = TRUE, status = "primary")
              )
      )
    )
  )
)

# ── SERVER ───────────────────────────────────────────────────
server <- function(input, output, session) {
  
  # Reactive filtered data
  filtered <- reactive({
    d <- df %>%
      filter(year >= input$year_range[1],
             year <= input$year_range[2],
             sex  %in% input$sex_filter,
             age  %in% input$age_filter)
    if (input$country_filter != "All")
      d <- d %>% filter(country == input$country_filter)
    d
  })
  
  # ── KPI Boxes ──────────────────────────────────────────────
  output$kpi_total_suicides <- renderValueBox({
    valueBox(
      format(sum(filtered()$suicides_no, na.rm = TRUE), big.mark = ","),
      "Total Suicides", icon = icon("skull"), color = "red"
    )
  })
  output$kpi_avg_rate <- renderValueBox({
    valueBox(
      round(mean(filtered()$suicides_per_100k, na.rm = TRUE), 2),
      "Avg Rate / 100k", icon = icon("percent"), color = "orange"
    )
  })
  output$kpi_peak_year <- renderValueBox({
    peak <- filtered() %>%
      group_by(year) %>%
      summarise(total = sum(suicides_no)) %>%
      slice_max(total, n = 1)
    valueBox(
      ifelse(nrow(peak) > 0, peak$year, "N/A"),
      "Peak Year", icon = icon("calendar"), color = "yellow"
    )
  })
  output$kpi_countries <- renderValueBox({
    valueBox(
      n_distinct(filtered()$country),
      "Countries", icon = icon("globe"), color = "blue"
    )
  })
  
  # ── Overview Charts ────────────────────────────────────────
  output$gen_bar <- renderPlotly({
    d <- filtered() %>%
      group_by(generation) %>%
      summarise(rate = mean(suicides_per_100k, na.rm = TRUE)) %>%
      arrange(desc(rate))
    plot_ly(d, x = ~reorder(generation, rate), y = ~rate,
            type = "bar", color = ~generation,
            colors = "Set2",
            hovertemplate = "<b>%{x}</b><br>Rate: %{y:.2f}<extra></extra>") %>%
      layout(xaxis = list(title = "Generation"),
             yaxis = list(title = "Avg Rate / 100k"),
             showlegend = FALSE)
  })
  
  output$sex_pie <- renderPlotly({
    d <- filtered() %>%
      group_by(sex) %>%
      summarise(total = sum(suicides_no, na.rm = TRUE))
    plot_ly(d, labels = ~sex, values = ~total, type = "pie",
            hole = 0.4,
            textinfo = "label+percent",
            hovertemplate = "<b>%{label}</b><br>Count: %{value:,}<extra></extra>")
  })
  
  output$age_box <- renderPlotly({
    d <- filtered()
    plot_ly(d, x = ~age, y = ~suicides_per_100k,
            type = "box", color = ~age, colors = "RdYlBu",
            hovertemplate = "Age: %{x}<br>Rate: %{y:.2f}<extra></extra>") %>%
      layout(xaxis = list(title = "Age Group"),
             yaxis = list(title = "Rate / 100k"),
             showlegend = FALSE)
  })
  
  # ── Time-Series ────────────────────────────────────────────
  output$ts_global <- renderPlotly({
    d <- filtered() %>%
      group_by(year) %>%
      summarise(total    = sum(suicides_no, na.rm = TRUE),
                avg_rate = mean(suicides_per_100k, na.rm = TRUE))
    plot_ly(d) %>%
      add_lines(x = ~year, y = ~total, name = "Total Suicides",
                line = list(color = "#e74c3c", width = 2)) %>%
      add_lines(x = ~year, y = ~avg_rate, name = "Avg Rate/100k",
                yaxis = "y2", line = list(color = "#3498db", dash = "dot")) %>%
      layout(
        yaxis  = list(title = "Total Suicides"),
        yaxis2 = list(title = "Rate / 100k", overlaying = "y", side = "right"),
        legend = list(orientation = "h"),
        hovermode = "x unified"
      )
  })
  
  output$ts_sex <- renderPlotly({
    d <- filtered() %>%
      group_by(year, sex) %>%
      summarise(rate = mean(suicides_per_100k, na.rm = TRUE), .groups = "drop")
    plot_ly(d, x = ~year, y = ~rate, color = ~sex,
            type = "scatter", mode = "lines",
            colors = c("#e74c3c","#3498db"),
            hovertemplate = "%{x}: %{y:.2f}<extra>%{fullData.name}</extra>") %>%
      layout(xaxis = list(title = "Year"),
             yaxis = list(title = "Rate / 100k"),
             hovermode = "x unified")
  })
  
  output$ts_age <- renderPlotly({
    d <- filtered() %>%
      group_by(year, age) %>%
      summarise(rate = mean(suicides_per_100k, na.rm = TRUE), .groups = "drop")
    plot_ly(d, x = ~year, y = ~rate, color = ~age,
            type = "scatter", mode = "lines",
            hovertemplate = "%{x}: %{y:.2f}<extra>%{fullData.name}</extra>") %>%
      layout(xaxis = list(title = "Year"),
             yaxis = list(title = "Rate / 100k"),
             hovermode = "x unified")
  })
  
  # ── Category Analysis ──────────────────────────────────────
  output$country_bar <- renderPlotly({
    d <- filtered() %>%
      group_by(country) %>%
      summarise(rate = mean(suicides_per_100k, na.rm = TRUE)) %>%
      slice_max(rate, n = 15)
    plot_ly(d, x = ~rate, y = ~reorder(country, rate),
            type = "bar", orientation = "h",
            marker = list(color = ~rate, colorscale = "Reds"),
            hovertemplate = "<b>%{y}</b><br>Rate: %{x:.2f}<extra></extra>") %>%
      layout(xaxis = list(title = "Avg Rate / 100k"),
             yaxis = list(title = ""))
  })
  
  output$age_sex_heat <- renderPlotly({
    d <- filtered() %>%
      group_by(age, sex) %>%
      summarise(rate = mean(suicides_per_100k, na.rm = TRUE), .groups = "drop")
    # Pivot for heatmap
    mat <- tidyr::pivot_wider(d, names_from = sex, values_from = rate)
    plot_ly(x = colnames(mat)[-1],
            y = mat$age,
            z = as.matrix(mat[,-1]),
            type = "heatmap",
            colorscale = "YlOrRd",
            hovertemplate = "Age: %{y}<br>Sex: %{x}<br>Rate: %{z:.2f}<extra></extra>") %>%
      layout(xaxis = list(title = "Sex"),
             yaxis = list(title = "Age Group"))
  })
  
  output$gen_line <- renderPlotly({
    d <- filtered() %>%
      group_by(year, generation) %>%
      summarise(rate = mean(suicides_per_100k, na.rm = TRUE), .groups = "drop")
    plot_ly(d, x = ~year, y = ~rate, color = ~generation,
            type = "scatter", mode = "lines+markers",
            hovertemplate = "%{x}: %{y:.2f}<extra>%{fullData.name}</extra>") %>%
      layout(xaxis = list(title = "Year"),
             yaxis = list(title = "Rate / 100k"),
             hovermode = "x unified")
  })
  
  # ── Correlations ───────────────────────────────────────────
  output$gdp_scatter <- renderPlotly({
    d <- filtered() %>% filter(!is.na(gdp_per_capita)) %>%
      group_by(country, year) %>%
      summarise(rate = mean(suicides_per_100k),
                gdp  = mean(gdp_per_capita), .groups = "drop")
    plot_ly(d, x = ~gdp, y = ~rate, text = ~country,
            type = "scatter", mode = "markers",
            marker = list(opacity = 0.6, size = 7, color = "#e74c3c"),
            hovertemplate = "<b>%{text}</b><br>GDP/cap: $%{x:,}<br>Rate: %{y:.2f}<extra></extra>") %>%
      layout(xaxis = list(title = "GDP per Capita ($)", type = "log"),
             yaxis = list(title = "Avg Rate / 100k"))
  })
  
  output$hdi_scatter <- renderPlotly({
    d <- filtered() %>% filter(!is.na(hdi)) %>%
      group_by(country, year) %>%
      summarise(rate = mean(suicides_per_100k),
                hdi  = mean(hdi), .groups = "drop")
    plot_ly(d, x = ~hdi, y = ~rate, text = ~country,
            type = "scatter", mode = "markers",
            marker = list(opacity = 0.6, size = 7, color = "#3498db"),
            hovertemplate = "<b>%{text}</b><br>HDI: %{x:.3f}<br>Rate: %{y:.2f}<extra></extra>") %>%
      layout(xaxis = list(title = "Human Development Index"),
             yaxis = list(title = "Avg Rate / 100k"))
  })
  
  output$pop_scatter <- renderPlotly({
    d <- filtered() %>%
      group_by(country, year) %>%
      summarise(suicides = sum(suicides_no),
                pop      = sum(population), .groups = "drop")
    plot_ly(d, x = ~pop, y = ~suicides, text = ~paste(country, year),
            type = "scatter", mode = "markers",
            marker = list(opacity = 0.5, size = 6, color = "#27ae60"),
            hovertemplate = "<b>%{text}</b><br>Pop: %{x:,}<br>Suicides: %{y:,}<extra></extra>") %>%
      layout(xaxis = list(title = "Population", type = "log"),
             yaxis = list(title = "Total Suicides", type = "log"))
  })
  
  # ── Data Table ─────────────────────────────────────────────
  output$raw_table <- renderDT({
    datatable(filtered(),
              filter   = "top",
              options  = list(pageLength = 15, scrollX = TRUE),
              rownames = FALSE)
  })
}

# ── Launch ───────────────────────────────────────────────────
shinyApp(ui = ui, server = server)