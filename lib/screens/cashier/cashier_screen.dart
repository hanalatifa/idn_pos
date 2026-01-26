import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:idn_pos/models/products.dart';
import 'package:idn_pos/screens/cashier/components/checkout_panel.dart';
import 'package:idn_pos/screens/cashier/components/printer_selector.dart';
import 'package:idn_pos/screens/cashier/components/product_card.dart';
import 'package:idn_pos/screens/cashier/components/qr_result_modal.dart';
import 'package:idn_pos/utils/currency_format.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

class CashierScreen extends StatefulWidget {
  const CashierScreen({super.key});

  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> {
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  List<BluetoothDevice> _device = [];
  BluetoothDevice? _selectedDevice;
  bool _connected = false;
  final Map<Product, int> _cart = {};

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  // LOGIKA BLUETOOTH
  Future<void> _initBluetooth() async {
    // minta ijin lokasi dan bluetooth ke user (WAJIB)
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location
    ].request();

    List<BluetoothDevice> devices = [
      // list ini akan otomatis ter isi jika bluethooth di handphone menyala dan sudah ada device yang sudah siap di koneksikan
    ];
    try {
      devices = await bluetooth.getBondedDevices(); // jika ada koneksi yang bisa di koneksi kan
    } catch (e) {
      debugPrint('error bluetooth: $e');
    }

    // kalo bener bener udah aktif
    if (mounted) {
      setState(() {
        _device = devices;
      });

      bluetooth.onStateChanged().listen((state) {
        if (mounted) {
          setState(() {
            _connected = state == BlueThermalPrinter.CONNECTED;
          });
        }
      });
    }
  }

  void _connectToDevice(BluetoothDevice? device) {
    // if (kondisi) utama, yang memplopori if-if selanjutnya
    if (device != null) { // kalo misal ada
      bluetooth.isConnected.then((isConnected) { // conect ga?
      // if yang merupakan cabang/anak dari if utama
      // if ini yang memiliki sebuah kondisi yang menjawab pertanyaan/statement
        if (isConnected = false) { // kalo misal ga conect padahal ada
          bluetooth.connect(device).catchError((error) { // menampilkan error, yang akan di jalankan ketika if kedua itu true
          // memiliki opini yang sama seperti ig yang ke dua (WAJIB)
            if (mounted) setState(() => _connected = false); // ngikutin yang atas, karna yang di atas juga false, harus satu suara sama yang atas
          });

          // statement di dalam if ini akan di jalankan ketika if-if sebelumnya tidak terpenuhi
          // if ini adalah opsi terakhir yang akan di jalankan ketika if sebelumnya tidak terpenuhi (tidak berjalan)
        if (mounted) setState(() => _selectedDevice = device); // "oh, device itu kepilih", punya opini sendiri, makanya beda, ada perubahan state lagi di line ini, dijalankan ketika device ini ada dan ke connect
        }
      });
    }
  }

  // LOGIKA CART
  void _addToCart(Product product) {
    setState(() {
      // ifAbsent kalo misalnya ga ada yang ditambah ya berarti segitu
      _cart.update(
        // untuk mendefiniskan product yang ada di menu
        product,
        // logika matematis, yang dijalankan ketika satu product sudah berada di keranjang dan klik + yang nantinya jumlahnya akan di tambah 1
       (value) => value + 1,
       // logika yang jika user tidak menambah kan lagi jumlah product (jumlah product hanya 1), maka default jumlah dari barang adalah 1
        ifAbsent: () => 1);
    });
  }

    void _removeFromCart(Product product) {
      setState(() {
        if (_cart.containsKey(product) && _cart[product]! > 1) {
          _cart[product] = _cart[product] ! - 1;
        } else {
          _cart.remove(product);
        }
      });
    }

    int _calculateTotal() {
      int total = 0;
      _cart.forEach((key, value) => total += (key.price * value)); // harga kali jumlah
      return total;
    }

    // LOGIKA PRINTING
    void _handlePrint() async {
      int total = _calculateTotal();
      if (total == 0) {
        ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("Kerangjang masi kosong!")));
      }

      String trxId = "TRX-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}";
      String qrData = "PAY:$trxId:$total";
      bool isPrinting = false;

      // menyiapkan tanggal saat ini (current date)
      DateTime now = DateTime.now();
      String formattedDate = DateFormat('dd-MM-yyyy HH:mm').format(now);

      // LAYOUTING STRUK
      if (_selectedDevice != null && await bluetooth.isConnected == true) {
        // header struk
        bluetooth.printNewLine();
        bluetooth.printCustom("IDN CAFE", 3, 1); // judul besar (center)
        bluetooth.printNewLine();
        bluetooth.printCustom("JL. Bagus Dayeuh", 1, 1); // alamat (center)

        // tanggal & ID
        bluetooth.printNewLine();
        bluetooth.printLeftRight("Waktu:", formattedDate, 1);

        // daftar items
        bluetooth.printCustom("--------------------------------", 1, 1);
        _cart.forEach((product, qty) {
          String priceTotal = formatRupiah(product.price *qty);
          // cetak nama barang x qty 
          bluetooth.printLeftRight("${product.name} x${qty}", priceTotal, 1);
          bluetooth.printCustom("--------------------------------", 1, 1);

          // total dan QR
          bluetooth.printLeftRight("TOTAL", formatRupiah(total), 3);
          bluetooth.printNewLine();
          bluetooth.printCustom("Scan QR Dibawah:", 1, 1);
          bluetooth.printQRcode(qrData, 200, 200, 1);
          bluetooth.printCustom("Terima Kasih"),
          bluetooth.printNewLine();
          bluetooth.printNewLine();
        });

        isPrinting = true;
      }

      // untuk menampilkan modal hasil QR Code (Popip)
      _showQRMOdal(qrData, total, isPrinting);
    }

    void _showQRMOdal(String qrData, int total, bool isPrinting) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => QrResultModal(
          qrData: qrData,
          total: total,
          isPrinting: isPrinting,
          onClose: () => Navigator.pop(context),
        )
      )
    }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          "Menu Kasir",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black87),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // DROPDOWN SELECT PRINTER
          PrinterSelector(
            devices: _device,
            selectedDevice: _selectedDevice,
            isConnected: _connected,
            onSelected: _connectToDevice,
          ),

          // Grid for poduct list
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.8,
                crossAxisSpacing: 15,
                mainAxisExtent: 15
              ),
              itemCount: menus.length,
              itemBuilder: (context, index) {
                final product = menus[index];
                final qyt = _cart[product] ?? 0;

                // pemanggilan product list pada product card
                return ProductCard(
                  product: product, 
                  qty: qyt, 
                  onAdd: () => _addToCart(product), 
                  onRemove: () => _removeFromCart(product),
                );
              },
            ),
          ),
          // Bottom sheet panel
          CheckoutPanel(
            total: _calculateTotal(),
            onPressed: _handlePrint,
          )
        ],
      ),
    );
  }
}