import std/times
import ./common

proc dNow(nodes: varargs[DeliNode]): DeliNode =
  argvars
  maxarg
  return DKDateTime(now())

proc dYear(nodes: varargs[DeliNode]): DeliNode =
  argvars
  nextArg dkDateTime
  maxarg
  return DKInt(arg.dtVal.year)
proc dMonth(nodes: varargs[DeliNode]): DeliNode =
  argvars
  nextArg dkDateTime
  maxarg
  return DKInt(arg.dtVal.month.int)
proc dDay(nodes: varargs[DeliNode]): DeliNode =
  argvars
  nextArg dkDateTime
  maxarg
  return DKInt(arg.dtVal.monthday)
proc dHour(nodes: varargs[DeliNode]): DeliNode =
  argvars
  nextArg dkDateTime
  maxarg
  return DKInt(arg.dtVal.hour)
proc dMinute(nodes: varargs[DeliNode]): DeliNode =
  argvars
  nextArg dkDateTime
  maxarg
  return DKInt(arg.dtVal.minute)
proc dSecond(nodes: varargs[DeliNode]): DeliNode =
  argvars
  nextArg dkDateTime
  maxarg
  return DKInt(arg.dtVal.second)
proc dNanos(nodes: varargs[DeliNode]): DeliNode =
  argvars
  nextArg dkDateTime
  maxarg
  return DKInt(arg.dtVal.nanosecond)

let DateTimeFunctions*: Table[string, proc(nodes: varargs[DeliNode]): DeliNode {.nimcall.} ] = {
  "now": dNow,
  "year": dYear,
  "month": dMonth,
  "day": dDay,
  "hour": dHour,
  "minute": dMinute,
  "second": dSecond,
  "nanosecond": dNanos,
}.toTable
