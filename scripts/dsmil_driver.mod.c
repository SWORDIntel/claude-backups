#include <linux/module.h>
#include <linux/export-internal.h>
#include <linux/compiler.h>

MODULE_INFO(name, KBUILD_MODNAME);

__visible struct module __this_module
__section(".gnu.linkonce.this_module") = {
	.name = KBUILD_MODNAME,
	.init = init_module,
#ifdef CONFIG_MODULE_UNLOAD
	.exit = cleanup_module,
#endif
	.arch = MODULE_ARCH_INIT,
};



static const struct modversion_info ____versions[]
__used __section("__versions") = {
	{ 0xd272d446, "__x86_return_thunk" },
	{ 0x766f04e3, "acpi_device_hid" },
	{ 0x431c3b7a, "_dev_info" },
	{ 0xe8a9936c, "acpi_match_device" },
	{ 0x431c3b7a, "_dev_err" },
	{ 0x247f43b9, "acpi_bus_unregister_driver" },
	{ 0xd272d446, "__fentry__" },
	{ 0xe8213e80, "_printk" },
	{ 0x8bb96703, "__acpi_bus_register_driver" },
	{ 0xab006604, "module_layout" },
};

static const u32 ____version_ext_crcs[]
__used __section("__version_ext_crcs") = {
	0xd272d446,
	0x766f04e3,
	0x431c3b7a,
	0xe8a9936c,
	0x431c3b7a,
	0x247f43b9,
	0xd272d446,
	0xe8213e80,
	0x8bb96703,
	0xab006604,
};
static const char ____version_ext_names[]
__used __section("__version_ext_names") =
	"__x86_return_thunk\0"
	"acpi_device_hid\0"
	"_dev_info\0"
	"acpi_match_device\0"
	"_dev_err\0"
	"acpi_bus_unregister_driver\0"
	"__fentry__\0"
	"_printk\0"
	"__acpi_bus_register_driver\0"
	"module_layout\0"
;

MODULE_INFO(depends, "");

MODULE_ALIAS("acpi*:DSMIL0D0:*");
MODULE_ALIAS("acpi*:DSMIL0D1:*");
MODULE_ALIAS("acpi*:DSMIL0D2:*");
MODULE_ALIAS("acpi*:DSMIL0D3:*");
MODULE_ALIAS("acpi*:DSMIL0D4:*");
MODULE_ALIAS("acpi*:DSMIL0D5:*");
MODULE_ALIAS("acpi*:DSMIL0D6:*");
MODULE_ALIAS("acpi*:DSMIL0D7:*");
MODULE_ALIAS("acpi*:DSMIL0D8:*");
MODULE_ALIAS("acpi*:DSMIL0D9:*");
MODULE_ALIAS("acpi*:DSMIL0DA:*");
MODULE_ALIAS("acpi*:DSMIL0DB:*");

MODULE_INFO(srcversion, "A4D197BA25FACB64E52D51C");
