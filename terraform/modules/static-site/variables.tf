variable "name_prefix" {
  type        = string
  description = "Prefix for globally unique resource names."
}

variable "environment" {
  type        = string
  description = "Banner label shown on the page (e.g. Dev, Prod)."

  validation {
    condition     = length(trimspace(var.environment)) > 0
    error_message = "environment must be a non-empty string."
  }
}

variable "page_template_path" {
  type        = string
  description = "HTML template with an __ENVIRONMENT__ placeholder."
}
