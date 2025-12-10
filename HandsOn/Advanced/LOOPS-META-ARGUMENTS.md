# Terraform Loops & Meta-Arguments — Comprehensive Interview Notes

This file consolidates interview-focused explanations for loops (`for_each`, `count`) and meta-arguments (`depends_on`, `lifecycle`, `create_before_destroy`, `ignore_changes`, `timeouts`).

---

## 1. for_each vs count

### Quick comparison table
| Feature | for_each | count |
|---------|----------|-------|
| Identity | Key-based (stable) | Index-based (positional) |
| Use case | Named/keyed resources | N identical resources |
| Splat syntax | Not directly | `[*]` works |
| Reference | `resource.name["key"]` | `resource.name[index]` |
| Changing order | Safe (keys don't shift) | Risky (indices shift, causes replace) |

### Short Q&A
- Q: When to use `count`?  
  A: For simple quantity-based scenarios where index identity is acceptable.

- Q: When to use `for_each`?  
  A: For keyed or named collections where resource identity should not depend on list order.

- Q: Can you use both on same resource?  
  A: No — a resource uses either `count`, `for_each`, or neither.

---

## 2. depends_on

### One-line definition
- Explicit dependency declaration to force resource creation order when implicit references don't exist.

### Short syntax
```hcl
resource "aws_instance" "app" {
  # ...
  depends_on = [aws_security_group.allow_ssh]
}
```

### Short Q&A
- Q: When to use `depends_on`?  
  A: When one resource depends on another but there's no implicit reference (e.g., side-effects or external actions).

- Q: What's the difference between implicit and explicit dependencies?  
  A: Implicit (via references like `resource.id`) is preferred; explicit (`depends_on`) is a last resort.

---

## 3. lifecycle

### One-line definition
- Meta-argument block controlling resource creation, update, and destruction behavior.

### Common options
- `create_before_destroy = true` — create replacement before destroying old (zero-downtime updates).
- `prevent_destroy = true` — fail if someone tries to destroy the resource.
- `ignore_changes = [attr1, attr2]` — ignore drift on specified attributes.
- `ignore_changes = all` — ignore all changes after initial creation.

### Short Q&A
- Q: When to use `create_before_destroy`?  
  A: For rolling updates or when you need zero downtime (e.g., load-balanced instances).

- Q: What does `prevent_destroy` do?  
  A: Blocks `terraform destroy` or `terraform apply` that would destroy the resource; useful for critical data stores.

- Q: When to use `ignore_changes`?  
  A: When external systems modify attributes that Terraform shouldn't revert (e.g., auto-scaling tags).

---

## 4. create_before_destroy

### One-line definition
- Lifecycle option that creates the new resource before destroying the old one.

### Benefit
- Zero-downtime updates (replacement happens while old resource still handles traffic).

### Example
```hcl
lifecycle {
  create_before_destroy = true
}
```

### Short Q&A
- Q: What's the alternative?  
  A: Normal (destroy then create) — causes brief downtime.

- Q: Does it apply to all resources?  
  A: No — useful for load-balanced stateless resources (EC2, ALB target groups); less relevant for databases.

---

## 5. ignore_changes

### One-line definition
- Prevent Terraform from detecting or reacting to changes in specific resource attributes.

### Example
```hcl
lifecycle {
  ignore_changes = [tags["ManagedByAWS"], auto_scaling_group_desired_count]
}
```

### Short Q&A
- Q: When to use `ignore_changes`?  
  A: When external systems or operators modify attributes that Terraform shouldn't override.

- Q: Can you ignore all changes?  
  A: Yes — `ignore_changes = all` (use cautiously; disables drift detection).

---

## 6. timeouts

### One-line definition
- Override default timeout durations for resource operations (create, read, update, delete).

### Example (not all resources support timeouts)
```hcl
timeouts {
  create = "10m"
  delete = "5m"
}
```

### Short Q&A
- Q: Do all resources have timeout options?  
  A: No — only some providers/resources support it; check provider docs.

- Q: When to increase timeouts?  
  A: When resources take longer than defaults (e.g., large database operations, complex provisioning).

---

## 7. Resource Meta-Arguments Summary (interview checklist)

| Meta-Argument | Purpose | Example |
|---------------|---------|---------|
| `count` | Create N identical resources | `count = 3` |
| `for_each` | Create keyed resources | `for_each = var.instances` |
| `depends_on` | Explicit dependency order | `depends_on = [resource.x]` |
| `lifecycle` | Control create/update/destroy | `create_before_destroy = true` |
| `timeouts` | Override operation timeouts | `create = "10m"` |

---

## Quick interview Q&A (all topics)

- Q: How to safely update a resource without downtime?  
  A: Use `lifecycle { create_before_destroy = true }` on load-balanced resources.

- Q: What's the safest way to prevent accidental deletion?  
  A: Add `lifecycle { prevent_destroy = true }` to critical resources; requires explicit removal of the block to destroy.

- Q: When should you use `depends_on` explicitly?  
  A: Only when you can't express the dependency via a reference (e.g., triggering external API calls or side-effects).

- Q: How to ignore auto-scaling tag changes?  
  A: `lifecycle { ignore_changes = [tags] }` or specify individual tags like `tags["AsgGroup"]`.

- Q: What's the difference between `count` and `for_each` when iterating?  
  A: `count` uses indices (fragile if list order changes); `for_each` uses keys (stable).

- Q: How to make a timeout longer?  
  A: Add `timeouts { create = "20m" }` in the resource block (if the provider supports it).

---

## Practical demo commands
```powershell
# Show resource metadata
terraform state show <resource_address>

# Test lifecycle prevent_destroy
terraform apply # will fail if prevent_destroy=true and resource marked for deletion

# Show dependencies
terraform graph | dot -Tpng > graph.png  # requires graphviz
```

---

## One-line closing summary
- "Use `for_each` for stable keyed resources, `count` for simple quantities, `depends_on` for explicit ordering, and `lifecycle` blocks to control zero-downtime updates, prevent accidents, and ignore external drift."

---

Generated: `HandsOn/Advanced/LOOPS-META-ARGUMENTS-INTERVIEW.md` (comprehensive, single-file reference)
