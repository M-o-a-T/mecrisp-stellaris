
ARMGNU?=arm-none-eabi

COPS = -Wall  -Os -nostdlib -nostartfiles -ffreestanding -save-temps
AOPS = --warn --fatal-warnings -I../common/

all : mecrisp-stellaris-stm32f051.bin 

mecrisp-stellaris-stm32f051.o : mecrisp-stellaris-stm32f051.s
	$(ARMGNU)-as $(AOPS) mecrisp-stellaris-stm32f051.s -o mecrisp-stellaris-stm32f051.o

mecrisp-stellaris-stm32f051.bin : memmap mecrisp-stellaris-stm32f051.o
	$(ARMGNU)-ld -o mecrisp-stellaris-stm32f051.elf -T memmap mecrisp-stellaris-stm32f051.o
	$(ARMGNU)-objdump -D mecrisp-stellaris-stm32f051.elf > mecrisp-stellaris-stm32f051.list
	$(ARMGNU)-objcopy mecrisp-stellaris-stm32f051.elf mecrisp-stellaris-stm32f051.bin -O binary

clean:
	rm -f *.bin
	rm -f *.o
	rm -f *.elf
	rm -f *.list
