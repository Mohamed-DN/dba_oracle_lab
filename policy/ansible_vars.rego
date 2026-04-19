package main

deny[msg] {
  not input.oracle_pdb_name
  msg := "oracle_pdb_name must be defined in automation/group_vars/all.yml"
}

deny[msg] {
  val := lower(tostring(input.app_user_password))
  contains(val, "changeme")
  msg := "app_user_password must not keep CHANGEME default"
}

deny[msg] {
  not input.switchover_require_confirmation
  msg := "switchover_require_confirmation must be true"
}
