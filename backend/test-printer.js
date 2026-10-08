const { ThermalPrinter, PrinterTypes, CharacterSet } = require("node-thermal-printer");

async function testPrinter() {
  console.log("Yazıcıya bağlanılıyor: 192.168.1.31...");

  let printer = new ThermalPrinter({
    type: PrinterTypes.EPSON,
    interface: "tcp://192.168.1.31:9100",
    characterSet: CharacterSet.PC857_TURKISH,
    removeSpecialCharacters: false,
    lineCharacter: "-",
    options: {
      timeout: 5000
    }
  });

  try {
    const isConnected = await printer.isPrinterConnected();
    if (!isConnected) {
      console.error("HATA: Yazıcıya ulaşılamadı. IP adresini ve bağlantıları kontrol edin.");
      return;
    }
    console.log("Bağlantı başarılı! Test sayfası yazdırılıyor...");

    printer.alignCenter();
    printer.println("NEXPOS TEST SAYFASI");
    printer.drawLine();
    printer.println("Eger bu yaziyi okuyabiliyorsaniz,");
    printer.println("yaziciniz basariyla calisiyor demektir!");
    printer.drawLine();
    printer.alignLeft();
    printer.println(`Tarih: ${new Date().toLocaleString("tr-TR")}`);
    printer.println(`IP: 192.168.1.31`);
    printer.println("");
    printer.alignCenter();
    printer.println("--- NEXPOS v2 ---");
    
    // Bip sesi ve kesme
    printer.beep(1, 2);
    printer.cut();

    await printer.execute();
    console.log("Yazdırma işlemi tamamlandı!");

  } catch (error) {
    console.error("Yazdırma sırasında bir hata oluştu:", error.message);
  }
}

testPrinter();
