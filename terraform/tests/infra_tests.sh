lambda_call() {
  aws lambda invoke --function-name lambda-cleanup-lambda-function out.txt
}
validate_efs_mount() {
  ssh -i ../ec2/node.pem ec2-user@$(cat ../ec2/publicIP.txt) mountpoint -q /wibble
}

create_file() {
  ssh -i ../ec2/node.pem ec2-user@$(cat ../ec2/publicIP.txt) touch /wibble/file
}
test_efs_mount() {
  assert_status_code 0 validate_efs_mount
}

test_lambda_is_accessible() {
  assert_status_code 0 lambda_call
}

test_efs_mount_is_writeable() {
  create_file

  assert "ssh -i ../ec2/node.pem ec2-user@$(cat ../ec2/publicIP.txt) test -e /wibble/file"
}

teardown_suite() {
  ssh -i ../ec2/node.pem ec2-user@$(cat ../ec2/publicIP.txt) rm /wibble/file
}
