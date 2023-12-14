library(ggplot2)
library(dplyr)
library(patchwork)
library(stringr)
library(tikzDevice)

use_tikz = TRUE

file_inter = "results-inter_stats-prepared.csv"
file_intra = "results-intra_stats-prepared.csv"

if (use_tikz) {
  lpos = c(0.17, 0.85)
} else {
  lpos = c(0.1, 0.85)
}

if (file.exists(file_inter)) {
  data_inter = read.csv(file = file_inter, sep=",", dec=".")
  
  data_inter["engine"][data_inter["engine"] == "fove.LiftedVarElim-cp"]  = "LVE (CP)"
  data_inter["engine"][data_inter["engine"] == "fove.LiftedVarElim-ccp"] = "LVE (ACP)"
  data_inter["engine"][data_inter["engine"] == "ve.VarElimEngine-cp"]    = "VE"
  data_inter = rename(data_inter, "Algorithm" = "engine")
  
  for (i in c(3)) { # c(3,5,10,15)
    data_filtered = filter(data_inter, p == i)
    if (nrow(data_filtered) == 0) next
    
    if (use_tikz) {
      tikz(paste("plot-pres-inter-p=", i, ".tex", sep=""), standAlone = FALSE, width = 3.3, height = 1.7)
    } else {
      pdf(file = paste("pres-inter-p=", i, ".pdf", sep=""), height = 2.4)
    }
    
    p <- ggplot(data_filtered, aes(x=d, y=mean_time, group=Algorithm, color=Algorithm)) +
      geom_line(aes(group=Algorithm, linetype=Algorithm, color=Algorithm)) +
      geom_point(aes(group=Algorithm, shape=Algorithm, color=Algorithm)) +
      geom_ribbon(
        aes(
          y = mean_time,
          ymin = mean_time - std,
          ymax = mean_time + std,
          fill = Algorithm
        ),
        alpha = 0.2,
        colour = NA
      ) +
      xlab("$d$") +
      ylab("time (ms)") +
      scale_y_log10() +
      theme_classic() +
      theme(
        axis.line.x = element_line(arrow = grid::arrow(length = unit(0.1, "cm"))),
        axis.line.y = element_line(arrow = grid::arrow(length = unit(0.1, "cm"))),
        legend.position = lpos,
        legend.title = element_blank(),
        legend.text = element_text(size=8),
        legend.background = element_rect(fill = NA),
        legend.spacing.y = unit(0, 'mm')
      ) +
      guides(fill = "none", ) +
      scale_color_manual(values=c(
        rgb(230,159,0, maxColorValue=255),
        rgb(0,77,64, maxColorValue=255),
        rgb(30,136,229, maxColorValue=255)
      )) +
      scale_fill_manual(values=c(
        rgb(230,159,0, maxColorValue=255),
        rgb(0,77,64, maxColorValue=255),
        rgb(30,136,229, maxColorValue=255)
      ))
    
    print(p)
    
    dev.off()
  }
}

if (file.exists(file_intra)) {
  data_intra = read.csv(file = file_intra, sep=",", dec=".")
  
  data_intra["engine"][data_intra["engine"] == "fove.LiftedVarElim-cp"]  = "LVE (CP)"
  data_intra["engine"][data_intra["engine"] == "fove.LiftedVarElim-ccp"] = "LVE (ACP)"
  data_intra["engine"][data_intra["engine"] == "ve.VarElimEngine-cp"]    = "VE"
  data_intra = rename(data_intra, "Algorithm" = "engine")
  
  for (i in c(1)) { # c(1,3,7)
    data_filtered = filter(data_intra, k == i)
    if (nrow(data_filtered) == 0) next
    
    if (use_tikz) {
      tikz(paste("plot-pres-intra-k=", i, ".tex", sep=""), standAlone = FALSE, width = 3.3, height = 1.7)
    } else {
      pdf(file = paste("pres-intra-k=", i, ".pdf", sep=""), height = 2.4)
    }
    
    p <- ggplot(data_filtered, aes(x=d, y=mean_time, group=Algorithm, color=Algorithm)) +
      geom_line(aes(group=Algorithm, linetype=Algorithm, color=Algorithm)) +
      geom_point(aes(group=Algorithm, shape=Algorithm, color=Algorithm)) +
      geom_ribbon(
        aes(
          y = mean_time,
          ymin = mean_time - std,
          ymax = mean_time + std,
          fill = Algorithm
        ),
        alpha = 0.2,
        colour = NA
      ) +
      xlab("$d$") +
      ylab("time (ms)") +
      scale_y_log10() +
      theme_classic() +
      theme(
        axis.line.x = element_line(arrow = grid::arrow(length = unit(0.1, "cm"))),
        axis.line.y = element_line(arrow = grid::arrow(length = unit(0.1, "cm"))),
        legend.position = lpos,
        legend.title = element_blank(),
        legend.text = element_text(size=8),
        legend.background = element_rect(fill = NA),
        legend.spacing.y = unit(0, 'mm')
      ) +
      guides(fill = "none", ) +
      scale_color_manual(values=c(
        rgb(230,159,0, maxColorValue=255),
        rgb(0,77,64, maxColorValue=255),
        rgb(30,136,229, maxColorValue=255)
      )) +
      scale_fill_manual(values=c(
        rgb(230,159,0, maxColorValue=255),
        rgb(0,77,64, maxColorValue=255),
        rgb(30,136,229, maxColorValue=255)
      ))
    
    print(p)
    
    dev.off()
  }
}
