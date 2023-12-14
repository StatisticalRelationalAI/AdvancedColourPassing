library(ggplot2)
library(dplyr)
library(patchwork)
library(stringr)
library(tikzDevice)

use_tikz = FALSE

file_inter = "results-inter_stats-offline-prepared.csv"
file_intra = "results-intra_stats-offline-prepared.csv"

if (use_tikz) {
  lpos_inter = c(0.86, 0.68)
  lpos_intra = c(0.1, 0.75)
} else {
  lpos_inter = "bottom"
  lpos_intra = "bottom"
}

if (file.exists(file_inter)) {
  data_inter = read.csv(file = file_inter, sep=",", dec=".")

  data_inter_filtered = filter(data_inter, d > 12)
  data_inter_filtered$p <- as.character(data_inter_filtered$p)

  if (use_tikz) {
    tikz("plot-offline-inter.tex", standAlone = FALSE, width = 3.3, height = 1.6)
  } else {
    pdf(file = "results-offline-inter.pdf", height = 2.4)
  }

  p <- ggplot(data_inter_filtered, aes(x=d, y=mean_alpha, group=p, color=p)) +
    geom_line(aes(group=p, linetype=p, color=p)) +
    geom_point(aes(group=p, shape=p, color=p)) +
    xlab("$d$") +
    ylab("$\\alpha$") +
    theme_classic() +
    theme(
      axis.line.x = element_line(arrow = grid::arrow(length = unit(0.1, "cm"))),
      axis.line.y = element_line(arrow = grid::arrow(length = unit(0.1, "cm"))),
      legend.position = lpos_inter,
      legend.title = element_blank(),
      legend.text = element_text(size=8),
      legend.background = element_rect(fill = NA),
      legend.spacing.y = unit(0, 'mm')
    ) +
    guides(fill = "none") +
    scale_color_manual(
      values = c(
        rgb(86,51,94,   maxColorValue=255),
        rgb(37,122,164, maxColorValue=255),
        rgb(78,155,133, maxColorValue=255),
        rgb(247,192,26, maxColorValue=255)
    ),
    breaks = c("3", "5", "10", "15"),
    labels = c("$p=0.03$", "$p=0.05$", "$p=0.1$", "$p=0.15$")
    ) +
    scale_linetype_discrete(
      breaks = c("3", "5", "10", "15"),
      labels = c("$p=0.03$", "$p=0.05$", "$p=0.1$", "$p=0.15$")
    ) + 
    scale_shape_discrete(
      breaks = c("3", "5", "10", "15"),
      labels = c("$p=0.03$", "$p=0.05$", "$p=0.1$", "$p=0.15$")
    )

  print(p)

  dev.off()
}

if (file.exists(file_intra)) {
  data_intra = read.csv(file = file_intra, sep=",", dec=".")

  data_intra_filtered = filter(data_intra, d > 2)
  data_intra_filtered$k <- as.character(data_intra_filtered$k)

  if (use_tikz) {
    tikz("plot-offline-intra.tex", standAlone = FALSE, width = 3.3, height = 1.6)
  } else {
    pdf(file = "results-offline-intra.pdf", height = 2.4)
  }

  p <- ggplot(data_intra_filtered, aes(x=d, y=mean_alpha, group=k, color=k)) +
    geom_line(aes(group=k, linetype=k, color=k)) +
    geom_point(aes(group=k, shape=k, color=k)) +
    xlab("$d$") +
    ylab("$\\alpha$") +
    theme_classic() +
    theme(
      axis.line.x = element_line(arrow = grid::arrow(length = unit(0.1, "cm"))),
      axis.line.y = element_line(arrow = grid::arrow(length = unit(0.1, "cm"))),
      legend.position = lpos_intra,
      legend.title = element_blank(),
      legend.text = element_text(size=8),
      legend.background = element_rect(fill = NA),
      legend.spacing.y = unit(0, 'mm')
    ) +
    guides(fill = "none") +
    scale_color_manual(
      values = c(
        rgb(37,122,164, maxColorValue=255),
        rgb(78,155,133, maxColorValue=255),
        rgb(247,192,26, maxColorValue=255)
      ),
      breaks = c("1", "3", "7"),
      labels = c("$k=1$", "$k=3$", "$k=7$")
    ) +
    scale_linetype_discrete(
      breaks = c("1", "3", "7"),
      labels = c("$k=1$", "$k=3$", "$k=7$")
    ) + 
    scale_shape_discrete(
      breaks = c("1", "3", "7"),
      labels = c("$k=1$", "$k=3$", "$k=7$")
    )

  print(p)

  dev.off()
}