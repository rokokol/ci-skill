# A document about an MCP server

`search_papers(query, max_results)` searches, `read_<source>_paper(paper_id, save_path)` reads, and `list_sources` names what there is

The reader prompt says: load "select:mcp__srv__read_SOURCE_paper,mcp__srv__download_with_fallback", then call mcp__srv__read_SOURCE_paper with paper_id PAPER_ID and save_path SAVE_PATH; if it fails, call mcp__srv__download_with_fallback with source SOURCE, paper_id PAPER_ID, and title when it is given

Never the user's spelling: `read_arXiv_paper` is not a tool <!-- check-interface: allow -->
