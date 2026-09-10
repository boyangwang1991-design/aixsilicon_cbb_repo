# SAF-005：A/B 关键逻辑必须维持在独立实例中；不允许跨边界重定时/合并。
set paths [get_cells -hierarchical -filter {ref_name =~ lockstep_comparator_logic_path*}]
if {[sizeof_collection $paths] == 0} {error "LCL_PATH_BOUNDARY_MISSING"}
set_ungroup $paths false
set_boundary_optimization $paths false
set_app_var compile_enable_register_merging false
