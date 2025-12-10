# Terraform `for_each` — Simple Explanation + Interview Notes

**Simple explanation**

- `for_each` iterates over a map or set, creating one resource per element and preserving keys.
- Resources are addressed by key: `resource.name["key"]`.
- Inside the resource use `each.key` and `each.value`.

**Short example**

```hcl
locals {
  servers = {
    web = { ami = "ami-0abc", az = "us-east-1a" }
    app = { ami = "ami-0def", az = "us-east-1b" }
  }
}

resource "aws_instance" "server" {
  for_each = local.servers
  ami           = each.value.ami
  availability_zone = each.value.az
  instance_type = "t2.micro"
  tags = { Name = each.key }
}
```

**When to use `for_each`**

- When you need stable identities based on keys (names, IDs, or other business identifiers).
- When each resource has different attributes or must be referenced by name.

**Common pitfalls**

- Using lists with `for_each` requires converting to a set/map for stable keys.
- Keys must be unique; changing keys causes destroy/create of that keyed resource.

**Interview-style Q&A (short answers)**

- Q: Why use `for_each` instead of `count`?
  - A: `for_each` preserves keys and provides stable identities; better for non-uniform or named resources.

- Q: How do you reference the resource created for key `web`?
  - A: `aws_instance.server["web"].id`.

- Q: What are `each.key` and `each.value`?
  - A: `each.key` is the map/set key; `each.value` is the element value (map element or set member).

- Q: What happens if you rename a key in the map used by `for_each`?
  - A: Terraform will treat the renamed key as a new resource and will destroy the resource with the old key (unless you use `terraform state` moves).

- Q: How to convert a list of objects into a `for_each` map?
  - A: Use `toset()` with a unique attribute or use `zipmap()` to build a map keyed by a unique field.

---
Generated: `HandsOn/Examples/for_each.md`