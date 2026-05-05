import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  _ClientesScreenState createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();
  final _montoCuotaController = TextEditingController();

  DateTime _fechaPago = DateTime.now();
  DateTime _fechaIngreso = DateTime.now();
  String _plan = 'Mensual';
  bool _activo = true;

  DocumentSnapshot? _clienteEditando;

  final List<String> _planes = [
    'Mensual',
    'Quincenal',
    'Semanal',
    'Clase Suelta',
  ];

  // Variables para el buscador
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Escuchar cambios en el campo de búsqueda
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Clientes',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar cliente por nombre o teléfono...',
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white70),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
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
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => _generarReporte(),
            tooltip: 'Reporte de clientes',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarFormulario(context),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Cliente'),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('clientes')
            .orderBy('nombre')
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.people_outline,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay clientes registrados',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _mostrarFormulario(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar Primer Cliente'),
                  ),
                ],
              ),
            );
          }

          // Filtrar clientes por búsqueda
          var clientes = snapshot.data!.docs;
          if (_searchQuery.isNotEmpty) {
            clientes = clientes.where((cliente) {
              final nombre = cliente['nombre'].toString().toLowerCase();
              final telefono = cliente['telefono'].toString().toLowerCase();
              return nombre.contains(_searchQuery) ||
                  telefono.contains(_searchQuery);
            }).toList();
          }

          if (clientes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No se encontraron clientes',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                    icon: const Icon(Icons.clear),
                    label: const Text('Limpiar búsqueda'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: clientes.length,
            itemBuilder: (context, index) {
              var cliente = clientes[index];
              return _buildClienteCard(cliente);
            },
          );
        },
      ),
    );
  }

  Widget _buildClienteCard(DocumentSnapshot cliente) {
    final fechaPago = (cliente['fechaPago'] as Timestamp).toDate();
    final diasRestantes = fechaPago.difference(DateTime.now()).inDays;
    Color estadoColor;
    String estadoTexto;

    if (diasRestantes < 0) {
      estadoColor = Colors.red;
      estadoTexto = 'VENCIDO';
    } else if (diasRestantes <= 3) {
      estadoColor = Colors.orange;
      estadoTexto = 'Por vencer';
    } else {
      estadoColor = Colors.green;
      estadoTexto = 'Al día';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: cliente['activo'] ? Colors.deepPurple : Colors.grey,
          child: Text(
            cliente['nombre'][0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          cliente['nombre'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tel: ${cliente['telefono']}'),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: estadoColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                estadoTexto,
                style: TextStyle(color: estadoColor, fontSize: 12),
              ),
            ),
          ],
        ),
        trailing: Icon(
          cliente['activo'] ? Icons.check_circle : Icons.cancel,
          color: cliente['activo'] ? Colors.green : Colors.red,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(Icons.phone, 'Teléfono', cliente['telefono']),
                const Divider(),
                _infoRow(
                  Icons.email,
                  'Email',
                  cliente['email'] ?? 'No registrado',
                ),
                const Divider(),
                _infoRow(
                  Icons.attach_money,
                  'Cuota',
                  '\$${cliente['montoCuota']}',
                ),
                const Divider(),
                _infoRow(Icons.calendar_today, 'Plan', cliente['plan']),
                const Divider(),
                _infoRow(
                  Icons.event,
                  'Próximo pago',
                  DateFormat('dd/MM/yyyy').format(fechaPago),
                ),
                const Divider(),
                _infoRow(
                  Icons.history,
                  'Días restantes',
                  '$diasRestantes días',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _registrarPago(cliente),
                      icon: const Icon(Icons.payment, size: 18),
                      label: const Text('Pago'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _mostrarFormulario(context, cliente),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Editar'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _verHistorialPagos(cliente.id),
                      icon: const Icon(Icons.history, size: 18),
                      label: const Text('Historial'),
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

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.deepPurple),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
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

  void _mostrarFormulario(BuildContext context, [DocumentSnapshot? cliente]) {
    _clienteEditando = cliente;

    if (cliente != null) {
      _nombreController.text = cliente['nombre'];
      _telefonoController.text = cliente['telefono'];
      _emailController.text = cliente['email'] ?? '';
      _montoCuotaController.text = cliente['montoCuota'].toString();
      _fechaPago = (cliente['fechaPago'] as Timestamp).toDate();
      _fechaIngreso = (cliente['fechaIngreso'] as Timestamp).toDate();
      _plan = cliente['plan'];
      _activo = cliente['activo'];
    } else {
      _nombreController.clear();
      _telefonoController.clear();
      _emailController.clear();
      _montoCuotaController.clear();
      _fechaPago = DateTime.now().add(const Duration(days: 30));
      _fechaIngreso = DateTime.now();
      _plan = 'Mensual';
      _activo = true;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(cliente == null ? 'Nuevo Cliente' : 'Editar Cliente'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _telefonoController,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email (opcional)',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _montoCuotaController,
                  decoration: const InputDecoration(
                    labelText: 'Monto de la cuota',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _plan,
                  decoration: const InputDecoration(
                    labelText: 'Plan',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  items: _planes
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) => setState(() => _plan = v!),
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('Fecha de ingreso'),
                  subtitle: Text(
                    DateFormat('dd/MM/yyyy').format(_fechaIngreso),
                  ),
                  leading: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _fechaIngreso,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) setState(() => _fechaIngreso = date);
                  },
                ),
                ListTile(
                  title: const Text('Próxima fecha de pago'),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(_fechaPago)),
                  leading: const Icon(Icons.warning),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _fechaPago,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) setState(() => _fechaPago = date);
                  },
                ),
                SwitchListTile(
                  title: const Text('Cliente activo'),
                  value: _activo,
                  onChanged: (v) => setState(() => _activo = v),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: _guardarCliente,
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _guardarCliente() async {
    if (_formKey.currentState!.validate()) {
      final data = {
        'nombre': _nombreController.text,
        'telefono': _telefonoController.text,
        'email': _emailController.text.isEmpty ? null : _emailController.text,
        'montoCuota': double.parse(_montoCuotaController.text),
        'plan': _plan,
        'fechaIngreso': _fechaIngreso,
        'fechaPago': _fechaPago,
        'activo': _activo,
        'ultimaActualizacion': FieldValue.serverTimestamp(),
      };

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        if (_clienteEditando == null) {
          final docRef = await FirebaseFirestore.instance
              .collection('clientes')
              .add(data);

          await FirebaseFirestore.instance.collection('pagos').add({
            'clienteId': docRef.id,
            'clienteNombre': _nombreController.text,
            'monto': double.parse(_montoCuotaController.text),
            'fechaPago': DateTime.now(),
            'metodoPago': 'Primer pago',
            'periodo': _formatearFecha(DateTime.now()),
          });
        } else {
          await _clienteEditando!.reference.update(data);
        }

        _clienteEditando = null;
        if (mounted) {
          Navigator.pop(context);
          Navigator.pop(context);

          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Cliente guardado correctamente'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  void _registrarPago(DocumentSnapshot cliente) async {
    String? metodoPagoSeleccionado;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Pago'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Cliente: ${cliente['nombre']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Monto a pagar: \$${cliente['montoCuota']}',
                  style: const TextStyle(fontSize: 20, color: Colors.green),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: metodoPagoSeleccionado,
                  hint: const Text('Seleccione método de pago'),
                  items: ['Efectivo', 'Tarjeta', 'Transferencia', 'QR']
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      metodoPagoSeleccionado = value;
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Método de pago',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Registrar Pago'),
          ),
        ],
      ),
    );

    if (result == true && metodoPagoSeleccionado != null) {
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        await FirebaseFirestore.instance.collection('pagos').add({
          'clienteId': cliente.id,
          'clienteNombre': cliente['nombre'],
          'monto': cliente['montoCuota'],
          'fechaPago': DateTime.now(),
          'metodoPago': metodoPagoSeleccionado,
          'periodo': _formatearFecha(DateTime.now()),
        });

        final fechaActualPago = (cliente['fechaPago'] as Timestamp).toDate();
        final nuevaFecha = fechaActualPago.add(const Duration(days: 30));
        await cliente.reference.update({'fechaPago': nuevaFecha});

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Pago registrado correctamente'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error al registrar pago: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  String _formatearFecha(DateTime fecha) {
    final meses = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return '${meses[fecha.month - 1]} ${fecha.year}';
  }

  void _verHistorialPagos(String clienteId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HistorialPagosScreen(clienteId: clienteId),
      ),
    );
  }

  void _generarReporte() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📊 Reporte generado (próximamente)')),
    );
  }
}

// Pantalla de historial de pagos
class HistorialPagosScreen extends StatelessWidget {
  final String clienteId;

  const HistorialPagosScreen({Key? key, required this.clienteId})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Pagos'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('pagos')
            .where('clienteId', isEqualTo: clienteId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 50, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Volver'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final pagos = snapshot.data!.docs;
          if (pagos.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No hay pagos registrados para este cliente'),
                  SizedBox(height: 8),
                  Text(
                    'Registre un pago desde la pantalla principal',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final pagosOrdenados = [...pagos];
          pagosOrdenados.sort((a, b) {
            final fechaA = a['fechaPago'] as Timestamp;
            final fechaB = b['fechaPago'] as Timestamp;
            return fechaB.compareTo(fechaA);
          });

          return ListView.builder(
            itemCount: pagosOrdenados.length,
            itemBuilder: (context, index) {
              var pago = pagosOrdenados[index];
              final fechaPago = (pago['fechaPago'] as Timestamp).toDate();

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.receipt, color: Colors.green),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '\$${pago['monto']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Método: ${pago['metodoPago']}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (pago['periodo'] != null)
                              Text(
                                'Periodo: ${pago['periodo']}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${fechaPago.day.toString().padLeft(2, '0')}/${fechaPago.month.toString().padLeft(2, '0')}/${fechaPago.year}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (pago['metodoPago'] == 'Primer pago')
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Primer pago',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
