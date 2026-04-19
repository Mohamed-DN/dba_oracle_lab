package main

deny[msg] {
  not input.profile_name
  msg := "profile_name is required in CIS-like profile"
}

deny[msg] {
  count(input.controls) < 10
  msg := "CIS-like profile must define at least 10 controls"
}

deny[msg] {
  some i
  control := input.controls[i]
  not control.id
  msg := sprintf("control at index %v is missing id", [i])
}

deny[msg] {
  some i
  control := input.controls[i]
  not control.check_command
  msg := sprintf("control %v is missing check_command", [control.id])
}
