# Conversation Types

This is the current plan for the conversations in the future, although it is not implemented yet.

| Type                   | Status      |
| ---------------------- | ----------- |
| Listed Conversations   | implemented |
| Unlisted Conversations | implemented |
| Project Conversations  | missing     |
| Snippets               | missing     |

## Listed Conversations

- Listed conversations appear in the selection screen and are saved to the conversations folder

## Unlisted Conversations

- Unlisted conversations are not saved and are wiped on switch
- They can be renamed and converted into a listed conversations

## Project Conversations

- Project Conversations are stored inside the project directory's conversations directory
- They have access to other project files if allowed in the project config

## Snipptes

- Unstructured and unlisted conversations
- Saved in a vector store
- Enriched with contextual information
  - creation time
  - previous k snippets
  - next l snippets
  - top n contextual snippets
