package main

is_ansible_vars {
  input.oracle_pdb_name
}

is_ansible_vars {
  input.switchover_require_confirmation
}

is_ansible_vars {
  input.app_user_password
}

deny[msg] {
  is_ansible_vars
  not input.oracle_pdb_name
  msg := "oracle_pdb_name must be defined in automation/group_vars/all.yml"
}

deny[msg] {
  is_ansible_vars
  val := lower(sprintf("%s", [input.app_user_password]))
  contains(val, "changeme")
  msg := "app_user_password must not keep CHANGEME default"
}

deny[msg] {
  is_ansible_vars
  not input.switchover_require_confirmation
  msg := "switchover_require_confirmation must be true"
}
