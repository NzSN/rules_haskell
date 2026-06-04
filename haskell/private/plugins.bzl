"""Utilities for GHC plugins."""

def resolve_plugin_tools(ctx, plugin_info):
    """Convert a plugin provider to a struct with tools."""
    return struct(
        module = plugin_info.module,
        deps = plugin_info.deps,
        args = plugin_info.args,
        tools = plugin_info.tools,
    )
