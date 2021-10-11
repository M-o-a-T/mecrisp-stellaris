
ARMGNU?=arm-none-eabi

COPS = -Wall  -Os -nostdlib -nostartfiles -ffreestanding -save-temps
AOPS = --warn --fatal-warnings -I../common/

all : mecrisp-stellaris-msp432p401r.bin 

mecrisp-stellaris-msp432p401r.o : mecrisp-stellaris-msp432p401r.s
	$(ARMGNU)-as $(AOPS) mecrisp-stellaris-msp432p401r.s -o mecrisp-stellaris-msp432p401r.o

mecrisp-stellaris-msp432p401r.bin : memmap mecrisp-stellaris-msp432p401r.o
	$(ARMGNU)-ld -o mecrisp-stellaris-msp432p401r.elf -T memmap mecrisp-stellaris-msp432p401r.o
	$(ARMGNU)-objdump -D mecrisp-stellaris-msp432p401r.elf > mecrisp-stellaris-msp432p401r.list
	$(ARMGNU)-objcopy mecrisp-stellaris-msp432p401r.elf mecrisp-stellaris-msp432p401r.bin -O binary

clean:
	rm -f *.bin
	rm -f *.o
	rm -f *.elf
	rm -f *.list
