def build(gen, env):
    env.lx_cargo_ws(gen, outs=['lxrustbenchs', 'starter', 'tcutest'])
    env.sub_build(gen, 'lxcppbenchs')
