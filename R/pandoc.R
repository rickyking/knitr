#' A Pandoc wrapper to convert Markdown documents to other formats
#'
#' This function calls Pandoc to convert Markdown documents to other formats
#' such as HTML, LaTeX/PDF and Word, etc, (optionally) based on a configuration
#' file or in-file configurations which specify the options to use for Pandoc.
#'
#' There are two ways to input the Pandoc configurations -- through a config
#' file, or embed the configurations in the markdown file as special comments
#' between \verb{<!--pandoc} and \verb{-->}.
#'
#' The configuration file is a DCF file (see \code{\link{read.dcf}}). This file
#' must contain a field named \code{format} which means the output format. The
#' configurations are written in the form of \code{tag:value} and passed to
#' Pandoc (if no value is needed, just leave it empty, e.g. the option
#' \code{standalone} or \code{s} for short). If there are multiple output
#' formats, write each format and relevant configurations in a block, and
#' separate blocks with blank lines.
#' @param input a character vector of the Markdown filenames
#' @param format the output format (see References); it can be a character
#'   vector of multiple formats
#' @param config the Pandoc configuration file; if missing, it is assumed to be
#'   a file with the same base name as the \code{input} file and an extension
#'   \code{.pandoc} (e.g. for \file{foo.md} it looks for \file{foo.pandoc})
#' @return The output filename(s) (or an error if the conversion failed).
#' @references Pandoc: \url{http://johnmacfarlane.net/pandoc/}; Examples and
#'   rules of the configurations: \url{http://yihui.name/knitr/demo/pandoc}
#' @seealso \code{\link{read.dcf}}
#' @export
#' @examples system('pandoc -h') # see possible output formats
pandoc = function(input, format = 'html', config = getOption('config.pandoc')) {
  if (Sys.which('pandoc') == '')
    stop('Please install pandoc first: http://johnmacfarlane.net/pandoc/')
  cfg = if (is.null(config)) sub_ext(input[1L], 'pandoc') else config
  txt = pandoc_cfg(readLines(input[1L], warn = FALSE))
  if (file.exists(cfg)) txt = c(txt, '', readLines(cfg, warn = FALSE))
  con = textConnection(txt); on.exit(close(con))
  cfg = read.dcf(con)
  mapply(pandoc_one, input, format, MoreArgs = list(cfg = cfg), USE.NAMES = FALSE)
}
# format is a scalar
pandoc_one = function(input, format, cfg) {
  cmn = NULL  # common arguments
  if (nrow(cfg) == 0L) cfg = character(0) else if (nrow(cfg) == 1L) {
    if ('format' %in% colnames(cfg)) {
      cfg = if (cfg[1L, 'format'] == format) drop(cfg) else NA
    } else {cmn = drop(cfg); cfg = NA}
  } else {
    if (!('format' %in% colnames(cfg)))
      stop('for a config file with multiple formats, there must be a field named "format"')
    if (sum(idx <- is.na(cfg[, 'format'])) > 1L)
      stop('at most one "format" field can be NA')
    if (sum(idx) == 1L) cmn = cfg[idx, ]
    cfg = cfg[!idx, , drop = FALSE]
    cfg = cfg[cfg[, 'format'] == format, ]
    if (!is.null(dim(cfg))) {
      if (nrow(cfg) > 1) stop('the output format is not unique in config')
      cfg = character(0) # nrow(cfg) == 0; format not found in cfg
    }
  }
  out = unname(if (!is.na(cfg['o'])) cfg['o'] else {
    if (!is.na(cfg['output'])) cfg['output'] else sub_ext(input, pandoc_ext(format))
  })
  cfg = cfg[setdiff(names(cfg), c('o', 'output', 'format'))]
  cmd = paste('pandoc', pandoc_arg(cfg), pandoc_arg(cmn), '-f markdown',
              '-t', format, '-o', out, paste(shQuote(input), collapse = ' '))
  message('executing ', cmd)
  if (system(cmd) == 0L) out else stop('conversion failed')
}

# infer output extension from format
pandoc_ext = function(format) {
  if (grepl('^html', format)) return('html')
  if (grepl('^latex|beamer|context|texinfo', format)) return('pdf')
  if (format %in% c('s5', 'slidy', 'slideous', 'dzslides')) return('html')
  if (grepl('^rst', format)) return('rst')
  if (format == 'opendocument') return('xml')
  format
}
# give me a vector of arguments, I turn them into commandline
pandoc_arg = function(x) {
  if (length(x) == 0L || all(is.na(x))) return()
  x = x[!is.na(x)]  # options not provided
  nms = names(x)
  if (any(grepl('\n', x))) {
    # one argument used multiple times, e.g. --bibliography
    x = str_split(x, '\n')
    nms = rep(nms, sapply(x, length))
    x = unlist(x)
  }
  a1 = nchar(nms) == 1L
  paste(ifelse(a1, '-', '--'), nms,
        ifelse(x == '', '', ifelse(a1, ' ', '=')), x, sep = '', collapse = ' ')
}
# identify pandoc config in markdown comments
pandoc_cfg = function(x) {
  if (length(i1 <- grep('^<!--pandoc', x)) == 0L ||
        length(i2 <- grep('-->\\s*$', x)) == 0L) return(character(0))
  i1 = i1[1L]; if (all(i2 < i1)) return(character(0))
  i2 = i2[i2 >= i1][1L]
  cfg = x[i1:i2]
  cfg[1L] = gsub('^<!--pandoc\\s*', '', cfg[1L])
  cfg[length(cfg)] = gsub('-->\\s*$', '', cfg[length(cfg)])
  cfg
}
