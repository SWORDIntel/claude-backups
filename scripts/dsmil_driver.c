// dsmil_driver.c - Corrected for kernel 6.14.0
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/acpi.h>
#include <linux/platform_device.h>

#define DSMIL_VERSION "1.0.0"

// Start with Layer 0 devices for testing
static const struct acpi_device_id dsmil_device_ids[] = {
    {"DSMIL0D0", 0}, {"DSMIL0D1", 1}, {"DSMIL0D2", 2}, {"DSMIL0D3", 3},
    {"DSMIL0D4", 4}, {"DSMIL0D5", 5}, {"DSMIL0D6", 6}, {"DSMIL0D7", 7},
    {"DSMIL0D8", 8}, {"DSMIL0D9", 9}, {"DSMIL0DA", 10}, {"DSMIL0DB", 11},
    {},
};
MODULE_DEVICE_TABLE(acpi, dsmil_device_ids);

static int dsmil_acpi_add(struct acpi_device *device)
{
    const struct acpi_device_id *id;
    
    id = acpi_match_device(dsmil_device_ids, &device->dev);
    if (!id) {
        dev_err(&device->dev, "DSMIL: Device ID not found\n");
        return -ENODEV;
    }
    
    dev_info(&device->dev, "DSMIL: Bound device %s (Layer 0, Device %ld)\n",
             acpi_device_hid(device), id->driver_data);
    
    device->driver_data = (void *)id->driver_data;
    
    return 0;
}

static void dsmil_acpi_remove(struct acpi_device *device)
{
    dev_info(&device->dev, "DSMIL: Unbound device %s\n", 
             acpi_device_hid(device));
}

// Correct structure initialization for kernel 6.14.0
static struct acpi_driver dsmil_acpi_driver = {
    .name = "dsmil",
    .class = "military",
    .ids = dsmil_device_ids,
    .ops = {
        .add = dsmil_acpi_add,
        .remove = dsmil_acpi_remove,
    },
    // .owner field removed - not needed in modern kernels
};

static int __init dsmil_init(void)
{
    int ret;
    
    pr_info("DSMIL: Driver v%s loading\n", DSMIL_VERSION);
    pr_info("DSMIL: Registering ACPI driver for 12 Layer 0 devices\n");
    
    ret = acpi_bus_register_driver(&dsmil_acpi_driver);
    if (ret) {
        pr_err("DSMIL: Failed to register ACPI driver: %d\n", ret);
        return ret;
    }
    
    pr_info("DSMIL: Successfully registered\n");
    return 0;
}

static void __exit dsmil_exit(void)
{
    acpi_bus_unregister_driver(&dsmil_acpi_driver);
    pr_info("DSMIL: Driver unloaded\n");
}

module_init(dsmil_init);
module_exit(dsmil_exit);

MODULE_LICENSE("GPL v2");
MODULE_AUTHOR("DSMIL Development Team");
MODULE_DESCRIPTION("Dell Secure Military Infrastructure Layer Driver");
MODULE_VERSION(DSMIL_VERSION);
MODULE_ALIAS("acpi:DSMIL*");