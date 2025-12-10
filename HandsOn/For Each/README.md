Examples: `for_each` and `count`

Short notes (clear, no extra explanation):

- for_each
  - Use when you need resources keyed by name (maps/sets).
  - Stable identity: `resource.name["key"]`.
  - Example file: `for_each.tf` creates `null_resource.server` for each map key.
  - Reference: `null_resource.server["web"].id`

- count
  - Use for N identical resources.
  - Indexed access: `resource.name[index]`.
  - Example file: `count.tf` creates `null_resource.web` with `count = var.instance_count`.
  - Reference: `null_resource.web[0].id`

Quick checklist:
- Use `for_each` with maps or sets to preserve keys.
- Use `count` for simple numeric quantities.
- Inside `for_each` resources use `each.key` and `each.value`.
- Inside `count` resources use `count.index`.

Files added:
- `for_each.tf`
- `count.tf`

Location: `HandsOn/Examples/`