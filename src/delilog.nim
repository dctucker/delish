
type Logger = object
  toStdErr: bool
  errors*: string

proc write*(logger: var Logger, str: varargs[string, `$`]) =
  if logger.toStdErr:
    for s in str:
      stderr.write(s)
  else:
    for s in str:
      logger.errors &= s

var errlog* = Logger(toStdErr: true)

proc setupStrErr*() =
  errlog.toStdErr = false

