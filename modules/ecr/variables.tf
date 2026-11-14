variable "name" {
  description = "Repository name"
  type        = string
}

variable "image_tag_mutability" {
  description = "IMMUTABLE: a pushed tag always names the same image, so promoting a tag between environments promotes the image that was tested. MUTABLE allows moving tags such as latest"
  type        = string
  default     = "IMMUTABLE"

  validation {
    condition     = contains(["IMMUTABLE", "MUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be IMMUTABLE or MUTABLE."
  }
}
