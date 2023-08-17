create_project -force meow_core ./project -part xc7a200tfbg676-1
add_files -quiet [glob -nocomplain ./myCPU/*/*.xci]

add_files -scan_for_includes ./myCPU

