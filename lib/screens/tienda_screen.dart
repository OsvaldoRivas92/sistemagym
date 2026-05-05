import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TiendaScreen extends StatefulWidget {
  @override
  _TiendaScreenState createState() => _TiendaScreenState();
}

class _TiendaScreenState extends State<TiendaScreen> {
  final _nombreController = TextEditingController();
  final _precioCompraController = TextEditingController();
  final _precioVentaController = TextEditingController();
  final _stockController = TextEditingController();
  final _cantidadController = TextEditingController();
  final _searchController = TextEditingController();

  String _searchQuery = '';
  String _categoriaSeleccionada = 'Todos';
  String _filtroStock = 'todos'; // todos, bajo, sinStock

  final List<String> _categorias = [
    'Todos',
    'Bebidas',
    'Suplementos',
    'Accesorios',
    'Ropa',
    'Otros',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nombreController.dispose();
    _precioCompraController.dispose();
    _precioVentaController.dispose();
    _stockController.dispose();
    _cantidadController.dispose();
    super.dispose();
  }

  String _formatearMiles(double numero) {
    final formatter = NumberFormat.currency(
      locale: 'es_PY',
      symbol: 'Gs. ',
      decimalDigits: 0,
    );
    return formatter.format(numero);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tienda / Inventario',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar producto...',
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white70),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                hintStyle: const TextStyle(color: Colors.white70),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory),
            onPressed: () => _mostrarResumenInventario(),
            tooltip: 'Resumen de inventario',
          ),
          IconButton(
            icon: const Icon(Icons.receipt),
            onPressed: () => _mostrarHistorialVentas(),
            tooltip: 'Historial de ventas',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros rápidos
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFiltroChip('Todos', Icons.all_inclusive),
                _buildFiltroChip('Bebidas', Icons.local_drink),
                _buildFiltroChip('Suplementos', Icons.fitness_center),
                _buildFiltroChip('Accesorios', Icons.watch),
                _buildFiltroChip('Ropa', Icons.checkroom),
              ],
            ),
          ),
          // Estadísticas rápidas
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('productos')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final productos = snapshot.data!.docs;
              int totalProductos = productos.length;
              int stockBajo = productos
                  .where((p) => (p['stock'] as int) <= 5)
                  .length;
              int sinStock = productos
                  .where((p) => (p['stock'] as int) == 0)
                  .length;
              double valorInventario = 0;
              for (var p in productos) {
                valorInventario +=
                    (p['precioCompra'] as num).toDouble() * (p['stock'] as int);
              }

              return Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      'Productos',
                      totalProductos.toString(),
                      Icons.inventory,
                    ),
                    _buildStatItem(
                      'Stock Bajo',
                      stockBajo.toString(),
                      Icons.warning,
                      color: Colors.orange,
                    ),
                    _buildStatItem(
                      'Sin Stock',
                      sinStock.toString(),
                      Icons.error,
                      color: Colors.red,
                    ),
                    _buildStatItem(
                      'Valor',
                      _formatearMiles(valorInventario),
                      Icons.attach_money,
                    ),
                  ],
                ),
              );
            },
          ),
          // Opciones de filtro de stock
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildFiltroStockChip('Todos', 'todos'),
              _buildFiltroStockChip('Stock Bajo (≤5)', 'bajo'),
              _buildFiltroStockChip('Sin Stock', 'sinStock'),
            ],
          ),
          const SizedBox(height: 8),
          // Lista de productos
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('productos')
                  .orderBy('nombre')
                  .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var productos = snapshot.data!.docs;

                // Aplicar filtros
                if (_searchQuery.isNotEmpty) {
                  productos = productos.where((p) {
                    final nombre = p['nombre'].toString().toLowerCase();
                    return nombre.contains(_searchQuery);
                  }).toList();
                }

                if (_categoriaSeleccionada != 'Todos') {
                  productos = productos.where((p) {
                    return p['categoria'] == _categoriaSeleccionada;
                  }).toList();
                }

                if (_filtroStock == 'bajo') {
                  productos = productos.where((p) {
                    return (p['stock'] as int) <= 5 && (p['stock'] as int) > 0;
                  }).toList();
                } else if (_filtroStock == 'sinStock') {
                  productos = productos.where((p) {
                    return (p['stock'] as int) == 0;
                  }).toList();
                }

                if (productos.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.inventory,
                          size: 80,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text('No hay productos'),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _mostrarFormularioProducto(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Agregar Producto'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: productos.length,
                  itemBuilder: (context, index) {
                    var prod = productos[index];
                    return _buildProductoCard(prod);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarFormularioProducto(context),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Producto'),
        backgroundColor: Colors.deepPurple,
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon, {
    Color color = Colors.deepPurple,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  Widget _buildFiltroChip(String categoria, IconData icon) {
    bool isSelected = _categoriaSeleccionada == categoria;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 4),
            Text(categoria),
          ],
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _categoriaSeleccionada = selected ? categoria : 'Todos';
          });
        },
        backgroundColor: Colors.grey.shade200,
        selectedColor: Colors.deepPurple.shade100,
        labelStyle: TextStyle(
          color: isSelected ? Colors.deepPurple : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildFiltroStockChip(String label, String valor) {
    bool isSelected = _filtroStock == valor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _filtroStock = selected ? valor : 'todos';
          });
        },
        backgroundColor: Colors.grey.shade200,
        selectedColor: Colors.deepPurple.shade100,
      ),
    );
  }

  Widget _buildProductoCard(DocumentSnapshot producto) {
    final stock = producto['stock'] as int;
    final precioVenta = (producto['precioVenta'] as num).toDouble();
    final precioCompra = (producto['precioCompra'] as num).toDouble();
    final ganancia = precioVenta - precioCompra;
    final gananciaPorcentaje = (ganancia / precioCompra) * 100;

    Color stockColor;
    String stockTexto;
    if (stock == 0) {
      stockColor = Colors.red;
      stockTexto = 'AGOTADO';
    } else if (stock <= 5) {
      stockColor = Colors.orange;
      stockTexto = 'STOCK BAJO';
    } else {
      stockColor = Colors.green;
      stockTexto = 'EN STOCK';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: stockColor.withOpacity(0.2),
          child: Icon(Icons.inventory, color: stockColor),
        ),
        title: Text(
          producto['nombre'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Precio: ${_formatearMiles(precioVenta)} | Stock: $stock'),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: stockColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                stockTexto,
                style: TextStyle(color: stockColor, fontSize: 10),
              ),
            ),
          ],
        ),
        trailing: Text(
          'Ganancia: ${_formatearMiles(ganancia)}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(
                  Icons.category,
                  'Categoría',
                  producto['categoria'] ?? 'Sin categoría',
                ),
                const Divider(),
                _infoRow(
                  Icons.trending_down,
                  'Precio Compra',
                  _formatearMiles(precioCompra),
                ),
                const Divider(),
                _infoRow(
                  Icons.attach_money,
                  'Precio Venta',
                  _formatearMiles(precioVenta),
                ),
                const Divider(),
                _infoRow(
                  Icons.trending_up,
                  'Ganancia',
                  '${_formatearMiles(ganancia)} (${gananciaPorcentaje.toStringAsFixed(1)}%)',
                  color: Colors.green,
                ),
                const Divider(),
                _infoRow(
                  Icons.inventory,
                  'Stock actual',
                  '$stock unidades',
                  color: stockColor,
                ),
                if (stock <= 5 && stock > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Stock bajo, se recomienda reponer pronto',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (stock == 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.error, color: Colors.red, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Producto agotado, reponer stock',
                              style: TextStyle(fontSize: 12, color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (stock > 0)
                      ElevatedButton.icon(
                        onPressed: () => _venderProducto(producto),
                        icon: const Icon(Icons.shopping_cart, size: 18),
                        label: const Text('Vender'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                      ),
                    ElevatedButton.icon(
                      onPressed: () => _ajustarStock(producto),
                      icon: const Icon(Icons.add_business, size: 18),
                      label: const Text('Ajustar Stock'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          _mostrarFormularioProducto(context, producto),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Editar'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _eliminarProducto(producto),
                      icon: const Icon(Icons.delete, size: 18),
                      label: const Text('Eliminar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    Color color = Colors.deepPurple,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _mostrarFormularioProducto(
    BuildContext context, [
    DocumentSnapshot? producto,
  ]) {
    if (producto != null) {
      _nombreController.text = producto['nombre'];
      _precioCompraController.text = producto['precioCompra'].toString();
      _precioVentaController.text = producto['precioVenta'].toString();
      _stockController.text = producto['stock'].toString();
    } else {
      _nombreController.clear();
      _precioCompraController.clear();
      _precioVentaController.clear();
      _stockController.clear();
    }

    String categoriaSeleccionada =
        producto != null && producto['categoria'] != null
        ? producto['categoria']
        : 'Bebidas';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              producto == null ? 'Nuevo Producto' : 'Editar Producto',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _nombreController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del producto',
                      prefixIcon: Icon(Icons.inventory),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: categoriaSeleccionada,
                    items: _categorias.where((c) => c != 'Todos').map((c) {
                      return DropdownMenuItem(value: c, child: Text(c));
                    }).toList(),
                    onChanged: (v) =>
                        setDialogState(() => categoriaSeleccionada = v!),
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      prefixIcon: Icon(Icons.category),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _precioCompraController,
                    decoration: const InputDecoration(
                      labelText: 'Precio de compra (Gs.)',
                      prefixIcon: Icon(Icons.trending_down),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _precioVentaController,
                    decoration: const InputDecoration(
                      labelText: 'Precio de venta (Gs.)',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _stockController,
                    decoration: const InputDecoration(
                      labelText: 'Stock inicial',
                      prefixIcon: Icon(Icons.inventory),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_nombreController.text.isEmpty) {
                    _mostrarSnackbar(
                      'Complete el nombre del producto',
                      Colors.red,
                    );
                    return;
                  }

                  final precioCompra =
                      double.tryParse(_precioCompraController.text) ?? 0;
                  final precioVenta =
                      double.tryParse(_precioVentaController.text) ?? 0;
                  final stock = int.tryParse(_stockController.text) ?? 0;

                  final data = {
                    'nombre': _nombreController.text,
                    'categoria': categoriaSeleccionada,
                    'precioCompra': precioCompra,
                    'precioVenta': precioVenta,
                    'stock': stock,
                    'ultimaActualizacion': FieldValue.serverTimestamp(),
                  };

                  if (producto == null) {
                    await FirebaseFirestore.instance
                        .collection('productos')
                        .add(data);
                    _registrarMovimientoStock(
                      'compra',
                      _nombreController.text,
                      stock,
                      0,
                      stock,
                    );
                  } else {
                    await producto.reference.update(data);
                  }

                  Navigator.pop(context);
                  _mostrarSnackbar(
                    producto == null
                        ? '✅ Producto agregado'
                        : '✅ Producto actualizado',
                    Colors.green,
                  );
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _ajustarStock(DocumentSnapshot producto) async {
    _cantidadController.clear();
    String tipoMovimiento = 'entrada';
    String motivo = '';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Ajustar Stock'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Producto: ${producto['nombre']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Stock actual: ${producto['stock']} unidades'),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'entrada',
                      label: Text('➕ Entrada'),
                      icon: Icon(Icons.add),
                    ),
                    ButtonSegment(
                      value: 'salida',
                      label: Text('➖ Salida'),
                      icon: Icon(Icons.remove),
                    ),
                  ],
                  selected: {tipoMovimiento},
                  onSelectionChanged: (set) =>
                      setDialogState(() => tipoMovimiento = set.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _cantidadController,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad',
                    prefixIcon: Icon(Icons.numbers),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (value) => motivo = value,
                  decoration: const InputDecoration(
                    labelText: 'Motivo (opcional)',
                    prefixIcon: Icon(Icons.description),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final cantidad = int.tryParse(_cantidadController.text) ?? 0;
                  if (cantidad <= 0) {
                    _mostrarSnackbar('Ingrese una cantidad válida', Colors.red);
                    return;
                  }

                  int nuevoStock = producto['stock'];
                  if (tipoMovimiento == 'entrada') {
                    nuevoStock += cantidad;
                  } else {
                    if (cantidad > nuevoStock) {
                      _mostrarSnackbar('No hay suficiente stock', Colors.red);
                      return;
                    }
                    nuevoStock -= cantidad;
                  }

                  await producto.reference.update({'stock': nuevoStock});
                  _registrarMovimientoStock(
                    tipoMovimiento == 'entrada' ? 'entrada' : 'salida',
                    producto['nombre'],
                    cantidad,
                    producto['stock'],
                    nuevoStock,
                    motivo,
                  );

                  Navigator.pop(context);
                  _mostrarSnackbar(
                    '✅ Stock ajustado: $nuevoStock unidades',
                    Colors.green,
                  );
                },
                child: const Text('Aplicar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _venderProducto(DocumentSnapshot producto) async {
    int cantidad = 1;

    final result = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Vender Producto'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Producto: ${producto['nombre']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Precio: ${_formatearMiles((producto['precioVenta'] as num).toDouble())}',
                ),
                const SizedBox(height: 8),
                Text('Stock disponible: ${producto['stock']}'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Cantidad: '),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) => setDialogState(
                          () => cantidad = int.tryParse(value) ?? 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total a pagar:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _formatearMiles(
                          (producto['precioVenta'] as num).toDouble() *
                              cantidad,
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, cantidad),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Vender'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null && result > 0) {
      int nuevoStock = producto['stock'] - result;
      if (nuevoStock < 0) {
        _mostrarSnackbar('Stock insuficiente', Colors.red);
        return;
      }

      await producto.reference.update({'stock': nuevoStock});

      // Registrar venta
      await FirebaseFirestore.instance.collection('ventas').add({
        'productoId': producto.id,
        'productoNombre': producto['nombre'],
        'cantidad': result,
        'precioUnitario': producto['precioVenta'],
        'total': (producto['precioVenta'] as num).toDouble() * result,
        'ganancia':
            ((producto['precioVenta'] as num).toDouble() -
                (producto['precioCompra'] as num).toDouble()) *
            result,
        'fecha': DateTime.now(),
        'fechaTimestamp': FieldValue.serverTimestamp(),
      });

      _registrarMovimientoStock(
        'venta',
        producto['nombre'],
        result,
        producto['stock'] + result,
        nuevoStock,
      );
      _mostrarSnackbar(
        '✅ Venta registrada. Total: ${_formatearMiles((producto['precioVenta'] as num).toDouble() * result)}',
        Colors.green,
      );
    }
  }

  void _registrarMovimientoStock(
    String tipo,
    String productoNombre,
    int cantidad,
    int stockAnterior,
    int stockNuevo, [
    String motivo = '',
  ]) {
    FirebaseFirestore.instance.collection('movimientos_stock').add({
      'tipo': tipo,
      'productoNombre': productoNombre,
      'cantidad': cantidad,
      'stockAnterior': stockAnterior,
      'stockNuevo': stockNuevo,
      'motivo': motivo,
      'fecha': DateTime.now(),
      'fechaTimestamp': FieldValue.serverTimestamp(),
    });
  }

  void _eliminarProducto(DocumentSnapshot producto) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Producto'),
        content: Text('¿Eliminar ${producto['nombre']} permanentemente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await producto.reference.delete();
      _mostrarSnackbar('🗑️ Producto eliminado', Colors.grey);
    }
  }

  void _mostrarResumenInventario() {
    showDialog(
      context: context,
      builder: (context) => FutureBuilder(
        future: Future.wait([
          FirebaseFirestore.instance.collection('productos').get(),
          FirebaseFirestore.instance
              .collection('movimientos_stock')
              .where(
                'fechaTimestamp',
                isGreaterThanOrEqualTo: DateTime(
                  DateTime.now().year,
                  DateTime.now().month,
                  1,
                ),
              )
              .get(),
        ]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final productos = snapshot.data![0].docs;
          final movimientos = snapshot.data![1].docs;

          int totalProductos = productos.length;
          int stockTotal = 0;
          double valorInventario = 0;
          int entradasMes = 0;
          int salidasMes = 0;

          for (var p in productos) {
            int stock = p['stock'] as int;
            stockTotal += stock;
            valorInventario += (p['precioCompra'] as num).toDouble() * stock;
          }

          for (var m in movimientos) {
            if (m['tipo'] == 'entrada' || m['tipo'] == 'compra') {
              entradasMes += m['cantidad'] as int;
            } else {
              salidasMes += m['cantidad'] as int;
            }
          }

          return AlertDialog(
            title: const Text('Resumen de Inventario'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _infoRow(
                  Icons.inventory,
                  'Productos',
                  totalProductos.toString(),
                ),
                const Divider(),
                _infoRow(
                  Icons.inventory_2,
                  'Unidades totales',
                  stockTotal.toString(),
                ),
                const Divider(),
                _infoRow(
                  Icons.attach_money,
                  'Valor inventario',
                  _formatearMiles(valorInventario),
                ),
                const Divider(),
                _infoRow(
                  Icons.add_box,
                  'Entradas del mes',
                  entradasMes.toString(),
                  color: Colors.green,
                ),
                const Divider(),
                _infoRow(
                  Icons.remove_shopping_cart,
                  'Salidas del mes',
                  salidasMes.toString(),
                  color: Colors.red,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _mostrarHistorialVentas() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HistorialVentasScreen()),
    );
  }

  void _mostrarSnackbar(String mensaje, Color color) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// Pantalla de historial de ventas
class HistorialVentasScreen extends StatelessWidget {
  const HistorialVentasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Ventas'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('ventas')
            .orderBy('fechaTimestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final ventas = snapshot.data!.docs;

          if (ventas.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No hay ventas registradas'),
                ],
              ),
            );
          }

          double totalVentas = 0;
          for (var v in ventas) {
            totalVentas += (v['total'] as num).toDouble();
          }

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Ventas:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      NumberFormat.currency(
                        locale: 'es_PY',
                        symbol: 'Gs. ',
                        decimalDigits: 0,
                      ).format(totalVentas),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: ventas.length,
                  itemBuilder: (context, index) {
                    final v = ventas[index];
                    final fecha = (v['fechaTimestamp'] as Timestamp).toDate();
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green,
                          child: const Icon(Icons.receipt, color: Colors.white),
                        ),
                        title: Text(v['productoNombre']),
                        subtitle: Text(
                          '${v['cantidad']} x ${NumberFormat.currency(locale: 'es_PY', symbol: 'Gs. ', decimalDigits: 0).format(v['precioUnitario'])}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              NumberFormat.currency(
                                locale: 'es_PY',
                                symbol: 'Gs. ',
                                decimalDigits: 0,
                              ).format(v['total']),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            Text(
                              DateFormat('dd/MM/yyyy HH:mm').format(fecha),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
