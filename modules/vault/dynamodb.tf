resource "aws_dynamodb_table" "vault_storage" {
  name = "vault"
  read_capacity = "${var.dynamodb_read_capacity}"
  write_capacity = "${var.dynamodb_write_capacity}"

  "attribute" {
    name = "Path"
    type = "S"
  }
  "attribute" {
    name = "Key"
    type = "S"
  }
  hash_key = "Path"
  range_key = "Key"

}
