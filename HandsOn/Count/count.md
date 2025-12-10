# Terraform `count` — Simple Explanation + Interview Notes

**Simple explanation**

- `count` creates N identical instances of a resource. It is an integer evaluated at plan time.
- Resources get indexed addresses: `resource.name[0]`, `resource.name[1]`, etc.
- Inside the resource use `count.index` to access the current index.

**Short example**

```hcl
variable "instance_count" { default = 2 }

resource "aws_instance" "web" {
  count = var.instance_count
  ami   = "ami-0123456789abcdef0"
  instance_type = "t2.micro"
  tags = { Name = "web-${count.index}" }
}
```

**When to use `count`**

- When you need a simple numeric quantity of identical resources.
- When resources do not need stable names keyed by business identifiers.

**Common pitfalls**

- Changing a collection's length can recreate resources — indexes are positional, not stable.
- Hard to reference a specific item by business key (use `for_each` for that).

**Interview-style Q&A (short answers)**

- Q: When should you prefer `count` over `for_each`?
  - A: Use `count` for N identical resources where identity by index is fine.

- Q: How do you reference the second resource created with `count = 3`?
  - A: `resource.name[1]` (zero-based index).

- Q: How to get the index inside the resource block?
  - A: Use `count.index`.

- Q: What happens if you change `count` from 2 to 3?
  - A: Terraform will plan to create one additional resource (index 2).

- Q: When can `count` cause unintended replacements?
  - A: When list ordering or length changes, indices shift and Terraform may recreate items. Use keyed `for_each` to avoid that.

---
Generated: `HandsOn/Examples/count.md`