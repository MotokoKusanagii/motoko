const std = @import("std");

pub fn Interface(Data: type) type {
    const data_info = @typeInfo(Data);

    if (data_info != std.builtin.Type.@"struct") {
        @compileError("Data has to be struct type");
    }

    const struct_info = data_info.@"struct";

    return struct {
        pub fn validate(T: type) void {
            // TODO: add field support
            // Validate methods
            for (struct_info.decls) |decl| {
                const name = decl.name;

                if (!@hasDecl(T, name)) {
                    @compileError("Type: " ++ @typeName(T) ++ " is missing method: " ++ name);
                }

                const data_fn = @field(Data, name);
                const t_fn = @field(T, name);

                const data_fn_info = @typeInfo(@TypeOf(data_fn)).@"fn";
                const t_fn_info = @typeInfo(@TypeOf(t_fn)).@"fn";

                // Check return value
                if (data_fn_info.return_type != t_fn_info.return_type) {
                    @compileError("Method " ++ name ++
                        " return type missmatch. Expected: " ++
                        @typeName(data_fn_info.return_type.?) ++
                        ", found: " ++
                        @typeName(t_fn_info.return_type.?));
                }

                // Check for self
                const data_has_self = data_fn_info.params.len > 0 and
                    (data_fn_info.params[0].type == Data or
                        data_fn_info.params[0].type == *Data);

                const t_has_self = t_fn_info.params.len > 0 and
                    (t_fn_info.params[0].type == T or
                        t_fn_info.params[0].type == *T);

                if (data_has_self != t_has_self) {
                    const hint = if (data_has_self) "instanced" else "static";
                    @compileError("Method " ++ name ++
                        " self parameter mismatch (static vs instance). Must be " ++ hint);
                }

                // Check param len
                const idx_start = if (data_has_self) 1 else 0;

                if (data_fn_info.params.len != t_fn_info.params.len) {
                    @compileError("Parameter count mismatch for " ++ name);
                }

                // Check param types (except self)
                inline for (data_fn_info.params[idx_start..], t_fn_info.params[idx_start..]) |data_param, t_param| {
                    if (data_param.type != t_param.type) {
                        @compileError("Parameter type mismatch in " ++ name);
                    }
                }
            }
        }
    };
}
