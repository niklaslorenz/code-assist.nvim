local Options = {
  model = "gpt-4o-mini",
  system_message = "You are a helpful programming assistant.",
  user_chat_color = "#a3be8c",
  assistant_chat_color = "#88c0d0",
  data_path = vim.fn.stdpath("data") .. "/code-assist",
  default_sort_order = "last",
}

return Options
