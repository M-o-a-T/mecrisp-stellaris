
ARMGNU?=arm-none-eabi

COPS = -Wall  -Os -nostdlib -nostartfiles -ffreestanding -save-temps
AOPS = --warn --fatal-warnings -I../common/

all : mecrisp-stellaris-stm32f030f4.bin 

mecrisp-stellaris-stm32f030f4.o : mecrisp-stellaris-stm32f030f4.s
	$(ARMGNU)-as $(AOPS) mecrisp-stellaris-stm32f030f4.s -o mecrisp-stellaris-stm32f030f4.o

mecrisp-stellaris-stm32f030f4.bin : memmap mecrisp-stellaris-stm32f030f4.o
	$(ARMGNU)-ld -o mecrisp-stellaris-stm32f030f4.elf -T memmap mecrisp-stellaris-stm32f030f4.o
	$(ARMGNU)-objdump -D mecrisp-stellaris-stm32f030f4.elf > mecrisp-stellaris-stm32f030f4.list
	$(ARMGNU)-objcopy mecrisp-stellaris-stm32f030f4.elf mecrisp-stellaris-stm32f030f4.bin -O binary

clean:
	rm -f *.bin
	rm -f *.o
	rm -f *.elf
	rm -f *.list
