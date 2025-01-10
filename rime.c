#include <lauxlib.h>
#include <rime_api.h>

#define DEFAULT_BUFFER_SIZE 1024

static RimeApi *rime_api = NULL;

static void vim_print(lua_State *L, const char *message_type, const char *message_value) {
  char message[DEFAULT_BUFFER_SIZE] = "";
  sprintf(message, "message_type: %s, message_value: %s", message_type, message_value);
  // 获取 vim.print 函数
  lua_getglobal(L, "vim");
  lua_getfield(L, -1, "print");

  // 压入参数
  lua_pushstring(L, message);

  // 调用函数 (1 个参数, 0 个返回值)
  if (lua_pcall(L, 1, 0, 0) != LUA_OK) {
    fprintf(stderr, "Error calling vim.print: %s\n", lua_tostring(L, -1));
    lua_pop(L, 1); // 移除错误消息
  }

  // 清理堆栈
  lua_pop(L, 1); // 移除 vim 表
}

static void notification_handler(void *context,
                          RimeSessionId session_id,
                          const char *message_type,
                          const char *message_value) {
  vim_print(context, message_type, message_value);
}

static int init(lua_State *L) {
  rime_api = rime_get_api();

  RIME_STRUCT(RimeTraits, rime_traits);
  lua_getfield(L, 1, "shared_data_dir");
  rime_traits.shared_data_dir = lua_tostring(L, -1);
  lua_getfield(L, 1, "user_data_dir");
  rime_traits.user_data_dir = lua_tostring(L, -1);
  lua_getfield(L, 1, "log_dir");
  rime_traits.log_dir = lua_tostring(L, -1);
  lua_getfield(L, 1, "distribution_name");
  rime_traits.distribution_name = lua_tostring(L, -1);
  lua_getfield(L, 1, "distribution_code_name");
  rime_traits.distribution_code_name = lua_tostring(L, -1);
  lua_getfield(L, 1, "distribution_version");
  rime_traits.distribution_version = lua_tostring(L, -1);
  lua_getfield(L, 1, "app_name");
  rime_traits.app_name = lua_tostring(L, -1);
  lua_getfield(L, 1, "min_log_level");
  rime_traits.min_log_level = lua_tointeger(L, -1);

  rime_api->setup(&rime_traits);
  rime_api->initialize(&rime_traits);
  rime_api->set_notification_handler(notification_handler, L);
  rime_api->start_maintenance(True);
  rime_api->join_maintenance_thread();
  return 0;
}

static int finalize(lua_State *L) {
  rime_api->finalize();
  return 0;
}

static int createSession(lua_State *L) {
  vim_print(L, "createSession", "createSession");
  RimeSessionId session_id = rime_api->create_session();
  if (session_id == 0)
    vim_print(L, "createSession", "cannot create session");
  lua_pushinteger(L, session_id);
  return 1;
}

static int destroySession(lua_State *L) {
  vim_print(L, "destroySession", "destroySession");
  RimeSessionId session_id = lua_tointeger(L, 1);
  Bool ret = rime_api->destroy_session(session_id);
  if (!ret)
    vim_print(L, "destroySession", "cannot destroy session");
  lua_pushboolean(L, ret);
  return 0;
}

static int getCurrentSchema(lua_State *L) {
  vim_print(L, "getCurrentSchema", "getCurrentSchema");
  RimeSessionId session_id = lua_tointeger(L, 1);
  char buffer[DEFAULT_BUFFER_SIZE] = "";
  if (!rime_api->get_current_schema(session_id, buffer, DEFAULT_BUFFER_SIZE)) {
    vim_print(L, "getCurrentSchema", "cannot get current schema");
    return 0;
  }
  lua_pushstring(L, buffer);
  return 1;
}

static int getSchemaList(lua_State *L) {
  vim_print(L, "getSchemaList", "getSchemaList");
  RimeSchemaList schema_list = {};
  if (!rime_api->get_schema_list(&schema_list)) {
    vim_print(L, "getSchemaList", "cannot get schema list");
    return 0;
  }
  lua_newtable(L);
  for (size_t i = 0; i < schema_list.size; i++) {
    lua_createtable(L, 0, 2);
    lua_pushstring(L, schema_list.list[i].schema_id);
    lua_setfield(L, -2, "schema_id");
    lua_pushstring(L, schema_list.list[i].name);
    lua_setfield(L, -2, "name");
    lua_rawseti(L, -2, i + 1);
  }
  return 1;
}

static int selectSchema(lua_State *L) {
  vim_print(L, "selectSchema", "selectSchema");
  RimeSessionId session_id = lua_tointeger(L, 1);
  Bool ret = rime_api->select_schema(session_id, lua_tostring(L, 2));
  if (!ret)
    vim_print(L, "selectSchema", "cannot select schema for session");
  lua_pushboolean(L, ret);
  return 1;
}

static int processKey(lua_State *L) {
  RimeSessionId session_id = lua_tointeger(L, 1);
  int key = lua_tointeger(L, 2);
  int mask = lua_tointeger(L, 3);
  char buffer[DEFAULT_BUFFER_SIZE] = "";
  int ret = rime_api->process_key(session_id, key, mask);
  sprintf(buffer, "session_id: %lu, key: %d, mask: %d ret: %d", session_id, key, mask, ret);
  vim_print(L, "processKey", buffer);
  lua_pushboolean(L, ret);
  return 1;
}

static int getContext(lua_State *L) {
  vim_print(L, "getContext", "getContext");
  RimeSessionId session_id = lua_tointeger(L, 1);
  RIME_STRUCT(RimeContext, context);
  if (!rime_api->get_context(session_id, &context)) {
    vim_print(L, "getContext", "cannot get context for session");
    return 0;
  }
  lua_createtable(L, 0, 2);
  lua_createtable(L, 0, 5);
  lua_pushinteger(L, context.composition.length);
  lua_setfield(L, -2, "length");
  lua_pushinteger(L, context.composition.cursor_pos);
  lua_setfield(L, -2, "cursor_pos");
  lua_pushinteger(L, context.composition.sel_start);
  lua_setfield(L, -2, "sel_start");
  lua_pushinteger(L, context.composition.sel_end);
  lua_setfield(L, -2, "sel_end");
  lua_pushstring(L, context.composition.preedit);
  lua_setfield(L, -2, "preedit");
  lua_setfield(L, -2, "composition");
  lua_createtable(L, 0, 7);
  lua_pushinteger(L, context.menu.page_size);
  lua_setfield(L, -2, "page_size");
  lua_pushinteger(L, context.menu.page_no);
  lua_setfield(L, -2, "page_no");
  lua_pushboolean(L, context.menu.is_last_page);
  lua_setfield(L, -2, "is_last_page");
  lua_pushinteger(L, context.menu.highlighted_candidate_index);
  lua_setfield(L, -2, "highlighted_candidate_index");
  lua_pushinteger(L, context.menu.num_candidates);
  lua_setfield(L, -2, "num_candidates");
  lua_pushstring(L, context.menu.select_keys);
  lua_setfield(L, -2, "select_keys");
  lua_newtable(L);
  for (int i = 0; i < context.menu.num_candidates; ++i) {
    lua_createtable(L, 0, 2);
    lua_pushstring(L, context.menu.candidates[i].text);
    lua_setfield(L, -2, "text");
    lua_pushstring(L, context.menu.candidates[i].comment);
    lua_setfield(L, -2, "comment");
    lua_rawseti(L, -2, i + 1);
  }
  lua_setfield(L, -2, "candidates");
  lua_setfield(L, -2, "menu");
  rime_api->free_context(&context);
  return 1;
}

static int getCommit(lua_State *L) {
  vim_print(L, "getCommit", "getCommit");
  RimeSessionId session_id = lua_tointeger(L, 1);
  RIME_STRUCT(RimeCommit, commit);
  if (!rime_api->get_commit(session_id, &commit)) {
    vim_print(L, "getCommit", "cannot get commit for session %lu\n");
    return 0;
  }
  lua_createtable(L, 0, 1);
  lua_pushstring(L, commit.text);
  lua_setfield(L, -2, "text");
  rime_api->free_commit(&commit);
  return 1;
}

static int commitComposition(lua_State *L) {
  vim_print(L, "commitComposition", "commitComposition");
  lua_pushboolean(L, rime_api->commit_composition(lua_tointeger(L, 1)));
  return 1;
}

static int clearComposition(lua_State *L) {
  vim_print(L, "clearComposition", "clearComposition");
  rime_api->clear_composition(lua_tointeger(L, 1));
  return 0;
}

static const luaL_Reg functions[] = {
    {"init", init},
    {"createSession", createSession},
    {"destroySession", destroySession},
    {"getCurrentSchema", getCurrentSchema},
    {"getSchemaList", getSchemaList},
    {"selectSchema", selectSchema},
    {"processKey", processKey},
    {"getContext", getContext},
    {"getCommit", getCommit},
    {"commitComposition", commitComposition},
    {"clearComposition", clearComposition},
    {"finalize", finalize},
    {NULL, NULL},
};

int luaopen_rime(lua_State *L) {
#if LUA_VERSION_NUM == 501
  luaL_register(L, "rime", functions);
#else
  luaL_newlib(L, functions);
#endif
  return 1;
}
