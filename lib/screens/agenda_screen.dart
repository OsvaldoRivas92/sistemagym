import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class AgendaScreen extends StatefulWidget {
  @override
  _AgendaScreenState createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  DateTime _focusedDay = DateTime.now();
  late DateTime _selectedDay;
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _montoTotalController = TextEditingController();
  final _montoSeniaController = TextEditingController();
  String _horaSeleccionada = '18:00';

  final List<String> _horarios = ['18:00', '19:00', '20:00', '21:00', '22:00'];
  Set<DateTime> _reservedDays = {};
  Map<DateTime, int> _reservasPorDia = {};

  // Función para normalizar fechas (quitar hora)
  DateTime _normalizarFecha(DateTime fecha) {
    return DateTime(fecha.year, fecha.month, fecha.day);
  }

  @override
  void initState() {
    super.initState();
    _selectedDay = _normalizarFecha(DateTime.now());
    _focusedDay = _normalizarFecha(DateTime.now());
    _cargarDiasReservados();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _montoTotalController.dispose();
    _montoSeniaController.dispose();
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

  String _formatearFechaLarga(DateTime fecha) {
    final dias = [
      'Domingo',
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
    ];
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
    return '${dias[fecha.weekday % 7]}, ${fecha.day} de ${meses[fecha.month - 1]} de ${fecha.year}';
  }

  String _formatearFechaCorta(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  void _cargarDiasReservados() {
    FirebaseFirestore.instance.collection('reservas').snapshots().listen((
      snapshot,
    ) {
      Set<DateTime> dias = {};
      Map<DateTime, int> conteo = {};

      for (var doc in snapshot.docs) {
        DateTime fecha = (doc['fecha'] as Timestamp).toDate();
        DateTime fechaSinHora = _normalizarFecha(fecha);
        dias.add(fechaSinHora);
        conteo[fechaSinHora] = (conteo[fechaSinHora] ?? 0) + 1;
      }

      if (mounted) {
        setState(() {
          _reservedDays = dias;
          _reservasPorDia = conteo;
        });
      }
    });
  }

  String _obtenerPrimerHorarioDisponible(Set<String> horariosOcupados) {
    for (var horario in _horarios) {
      if (!horariosOcupados.contains(horario)) {
        return horario;
      }
    }
    return _horarios.first;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda Cancha'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => _mostrarResumenMensual(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _agendarReserva(context),
        icon: const Icon(Icons.add),
        label: const Text('Nueva Reserva'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          TableCalendar(
            focusedDay: _focusedDay,
            firstDay: DateTime.now(),
            lastDay: DateTime(2030),
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = _normalizarFecha(selected);
                _focusedDay = _normalizarFecha(focused);
              });
            },
            calendarStyle: CalendarStyle(
              markersMaxCount: 1,
              markerDecoration: const BoxDecoration(
                color: Colors.deepPurple,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.deepPurple.shade100,
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: Colors.deepPurple,
                shape: BoxShape.circle,
              ),
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                final fechaSinHora = _normalizarFecha(day);
                if (_reservedDays.contains(fechaSinHora)) {
                  final cantidad = _reservasPorDia[fechaSinHora] ?? 0;
                  return Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.deepPurple,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$cantidad',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  );
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 8),
          _buildResumenDelDia(),
          const Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              key: ValueKey(_selectedDay),
              stream: FirebaseFirestore.instance
                  .collection('reservas')
                  .where('fecha', isEqualTo: _selectedDay)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final reservas = snapshot.data!.docs;
                reservas.sort(
                  (a, b) =>
                      (a['hora'] as String).compareTo(b['hora'] as String),
                );

                if (reservas.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.sports_soccer,
                          size: 80,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text('No hay reservas para este día'),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _agendarReserva(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Agendar Reserva'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: reservas.length,
                  itemBuilder: (context, index) {
                    return _buildReservaCard(reservas[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenDelDia() {
    final fechaClave = _normalizarFecha(_selectedDay);
    int cantidadReservas = _reservasPorDia[fechaClave] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatearFechaLarga(_selectedDay),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Total reservas: $cantidadReservas',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          if (cantidadReservas > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$cantidadReservas reserva${cantidadReservas == 1 ? "" : "s"}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReservaCard(DocumentSnapshot reserva) {
    final estadoPago = reserva['estadoPago'] ?? 'Pendiente';
    final montoTotal = (reserva['montoTotal'] as num?)?.toDouble() ?? 0;
    final montoSenia = (reserva['montoSenia'] as num?)?.toDouble() ?? 0;
    final montoRestante =
        (reserva['montoRestante'] as num?)?.toDouble() ??
        (montoTotal - montoSenia);

    Color estadoColor;
    IconData estadoIcono;
    String estadoTexto;

    switch (estadoPago) {
      case 'Pagado':
        estadoColor = Colors.green;
        estadoIcono = Icons.check_circle;
        estadoTexto = 'Pagado';
        break;
      case 'Señal':
        estadoColor = Colors.orange;
        estadoIcono = Icons.warning;
        estadoTexto = 'Seña: ${_formatearMiles(montoSenia)}';
        break;
      default:
        estadoColor = Colors.red;
        estadoIcono = Icons.pending;
        estadoTexto = 'Pendiente';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: estadoColor,
          child: Icon(estadoIcono, color: Colors.white, size: 20),
        ),
        title: Text(
          reserva['nombre'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Hora: ${reserva['hora']} | Tel: ${reserva['telefono']}',
        ),
        trailing: Text(
          estadoTexto,
          style: TextStyle(color: estadoColor, fontWeight: FontWeight.bold),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(Icons.person, 'Cliente', reserva['nombre']),
                const Divider(),
                _infoRow(Icons.phone, 'Teléfono', reserva['telefono']),
                const Divider(),
                _infoRow(Icons.access_time, 'Hora', reserva['hora']),
                const Divider(),
                _infoRow(
                  Icons.attach_money,
                  'Monto total',
                  _formatearMiles(montoTotal),
                ),
                if (montoSenia > 0) ...[
                  const Divider(),
                  _infoRow(
                    Icons.payment,
                    'Seña registrada',
                    _formatearMiles(montoSenia),
                    color: Colors.green,
                  ),
                ],
                if (montoRestante > 0) ...[
                  const Divider(),
                  _infoRow(
                    Icons.money_off,
                    'Saldo pendiente',
                    _formatearMiles(montoRestante),
                    color: Colors.orange,
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (estadoPago == 'Pendiente')
                      ElevatedButton.icon(
                        onPressed: () => _registrarSenia(reserva, montoTotal),
                        icon: const Icon(Icons.payment, size: 18),
                        label: const Text('Registrar Seña'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                      ),
                    if (estadoPago == 'Señal')
                      ElevatedButton.icon(
                        onPressed: () => _pagarRestante(reserva, montoRestante),
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: Text(
                          'Pagar Restante (${_formatearMiles(montoRestante)})',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                      ),
                    if (estadoPago != 'Pagado')
                      ElevatedButton.icon(
                        onPressed: () =>
                            _pagarTodo(reserva, montoTotal, montoSenia),
                        icon: const Icon(Icons.payment, size: 18),
                        label: const Text('Pagar Todo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => _editarReserva(reserva),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Editar'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _eliminarReserva(reserva),
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
            width: 120,
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

  void _agendarReserva(BuildContext context) {
    FirebaseFirestore.instance
        .collection('reservas')
        .where('fecha', isEqualTo: _selectedDay)
        .get()
        .then((snapshot) {
          Set<String> horariosOcupados = {};
          for (var doc in snapshot.docs) {
            horariosOcupados.add(doc['hora'] as String);
          }
          _mostrarDialogoAgendar(horariosOcupados);
        });
  }

  void _mostrarDialogoAgendar(Set<String> horariosOcupados) {
    _nombreController.clear();
    _telefonoController.clear();
    _montoTotalController.clear();
    _montoSeniaController.clear();
    _horaSeleccionada = _obtenerPrimerHorarioDisponible(horariosOcupados);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          double montoTotal = 0;
          double montoSenia = 0;

          return AlertDialog(
            title: Text(
              'Nueva Reserva - ${_formatearFechaCorta(_selectedDay)}',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _nombreController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _telefonoController,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _montoTotalController,
                    decoration: const InputDecoration(
                      labelText: 'Monto total (Gs.)',
                      prefixIcon: Icon(Icons.attach_money),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => setDialogState(
                      () => montoTotal = double.tryParse(value) ?? 0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _montoSeniaController,
                    decoration: InputDecoration(
                      labelText: 'Monto de seña (Gs.)',
                      prefixIcon: const Icon(Icons.payment),
                      border: const OutlineInputBorder(),
                      helperText: montoTotal > 0
                          ? 'Restante: ${_formatearMiles(montoTotal - montoSenia)}'
                          : null,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => setDialogState(() {
                      montoSenia = double.tryParse(value) ?? 0;
                      if (montoSenia > montoTotal) montoSenia = montoTotal;
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _horaSeleccionada,
                    items: _horarios.map((h) {
                      bool ocupado = horariosOcupados.contains(h);
                      return DropdownMenuItem(
                        value: h,
                        enabled: !ocupado,
                        child: Row(
                          children: [
                            Text(h),
                            if (ocupado) ...[
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.block,
                                color: Colors.red,
                                size: 16,
                              ),
                              const Text(
                                ' (Ocupado)',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _horaSeleccionada = v!),
                    decoration: const InputDecoration(
                      labelText: 'Hora',
                      prefixIcon: Icon(Icons.access_time),
                    ),
                  ),
                  if (montoTotal > 0) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _infoRow(
                            Icons.attach_money,
                            'Total',
                            _formatearMiles(montoTotal),
                          ),
                          const Divider(),
                          _infoRow(
                            Icons.payment,
                            'Seña',
                            _formatearMiles(montoSenia),
                            color: montoSenia > 0 ? Colors.green : Colors.grey,
                          ),
                          const Divider(),
                          _infoRow(
                            Icons.money_off,
                            'Saldo',
                            _formatearMiles(montoTotal - montoSenia),
                            color: (montoTotal - montoSenia) > 0
                                ? Colors.orange
                                : Colors.green,
                          ),
                        ],
                      ),
                    ),
                  ],
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
                  final montoTotalFinal =
                      double.tryParse(_montoTotalController.text) ?? 0;
                  final montoSeniaFinal =
                      double.tryParse(_montoSeniaController.text) ?? 0;

                  if (_nombreController.text.isEmpty ||
                      _telefonoController.text.isEmpty) {
                    _mostrarSnackbar(
                      'Complete los campos requeridos',
                      Colors.red,
                    );
                    return;
                  }
                  if (montoTotalFinal <= 0) {
                    _mostrarSnackbar(
                      'Ingrese un monto total válido',
                      Colors.red,
                    );
                    return;
                  }
                  if (horariosOcupados.contains(_horaSeleccionada)) {
                    _mostrarSnackbar(
                      'Este horario ya está ocupado',
                      Colors.red,
                    );
                    return;
                  }

                  final montoRestante = montoTotalFinal - montoSeniaFinal;
                  final estadoPago = montoSeniaFinal >= montoTotalFinal
                      ? 'Pagado'
                      : (montoSeniaFinal > 0 ? 'Señal' : 'Pendiente');

                  await FirebaseFirestore.instance.collection('reservas').add({
                    'nombre': _nombreController.text,
                    'telefono': _telefonoController.text,
                    'fecha': _selectedDay,
                    'hora': _horaSeleccionada,
                    'estadoPago': estadoPago,
                    'montoTotal': montoTotalFinal,
                    'montoSenia': montoSeniaFinal,
                    'montoRestante': montoRestante > 0 ? montoRestante : 0,
                    'fechaReserva': FieldValue.serverTimestamp(),
                  });

                  Navigator.pop(context);
                  _mostrarSnackbar(
                    '✅ Reserva agendada correctamente',
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

  void _registrarSenia(DocumentSnapshot reserva, double montoTotal) async {
    double nuevaSenia = 0;
    final senaActual = (reserva['montoSenia'] as num?)?.toDouble() ?? 0;
    final saldoActual = montoTotal - senaActual;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Seña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Cliente: ${reserva['nombre']}'),
            Text('Monto total: ${_formatearMiles(montoTotal)}'),
            if (senaActual > 0)
              Text('Seña actual: ${_formatearMiles(senaActual)}'),
            Text(
              'Saldo pendiente: ${_formatearMiles(saldoActual)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: senaActual > 0
                    ? 'Monto adicional (Gs.)'
                    : 'Monto de la seña (Gs.)',
                prefixIcon: const Icon(Icons.attach_money),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => nuevaSenia = double.tryParse(value) ?? 0,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nuevaSenia > 0 && nuevaSenia <= saldoActual) {
                Navigator.pop(context, true);
              } else {
                _mostrarSnackbar(
                  'Ingrese un monto válido (máximo ${_formatearMiles(saldoActual)})',
                  Colors.red,
                );
              }
            },
            child: const Text('Registrar'),
          ),
        ],
      ),
    );

    if (result == true) {
      final totalSenia = senaActual + nuevaSenia;
      final nuevoSaldo = montoTotal - totalSenia;

      await reserva.reference.update({
        'estadoPago': nuevoSaldo <= 0 ? 'Pagado' : 'Señal',
        'montoSenia': totalSenia,
        'montoRestante': nuevoSaldo > 0 ? nuevoSaldo : 0,
      });

      _mostrarSnackbar(
        '✅ Seña de ${_formatearMiles(nuevaSenia)} registrada. Saldo: ${_formatearMiles(nuevoSaldo)}',
        Colors.green,
      );
    }
  }

  void _pagarRestante(DocumentSnapshot reserva, double saldoActual) async {
    double montoPagar = 0;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pagar Saldo Restante'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Cliente: ${reserva['nombre']}'),
            Text(
              'Saldo pendiente: ${_formatearMiles(saldoActual)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Monto a pagar (Gs.)',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => montoPagar = double.tryParse(value) ?? 0,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (montoPagar > 0 && montoPagar <= saldoActual) {
                Navigator.pop(context, true);
              } else {
                _mostrarSnackbar('Ingrese un monto válido', Colors.red);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Pagar'),
          ),
        ],
      ),
    );

    if (result == true) {
      final senaActual = (reserva['montoSenia'] as num?)?.toDouble() ?? 0;
      final montoTotal = (reserva['montoTotal'] as num).toDouble();
      final nuevaSenia = senaActual + montoPagar;
      final nuevoSaldo = montoTotal - nuevaSenia;

      await reserva.reference.update({
        'estadoPago': nuevoSaldo <= 0 ? 'Pagado' : 'Señal',
        'montoSenia': nuevaSenia,
        'montoRestante': nuevoSaldo > 0 ? nuevoSaldo : 0,
      });

      _mostrarSnackbar(
        '✅ Pago de ${_formatearMiles(montoPagar)} registrado. Saldo: ${_formatearMiles(nuevoSaldo)}',
        Colors.green,
      );
    }
  }

  void _pagarTodo(
    DocumentSnapshot reserva,
    double montoTotal,
    double senaActual,
  ) async {
    final saldoPendiente = montoTotal - senaActual;
    double montoPagar = saldoPendiente;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pagar Todo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Cliente: ${reserva['nombre']}'),
            Text('Monto total: ${_formatearMiles(montoTotal)}'),
            if (senaActual > 0)
              Text('Seña ya pagada: ${_formatearMiles(senaActual)}'),
            const Divider(),
            Text(
              'Saldo pendiente: ${_formatearMiles(saldoPendiente)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: 'Monto a pagar (Gs.)',
                prefixIcon: const Icon(Icons.attach_money),
                border: const OutlineInputBorder(),
                hintText: _formatearMiles(saldoPendiente),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => montoPagar = double.tryParse(value) ?? 0,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (montoPagar > 0 && montoPagar <= saldoPendiente) {
                Navigator.pop(context, true);
              } else {
                _mostrarSnackbar(
                  'Ingrese un monto válido (máximo ${_formatearMiles(saldoPendiente)})',
                  Colors.red,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Pagar'),
          ),
        ],
      ),
    );

    if (result == true) {
      final nuevaSenia = senaActual + montoPagar;

      await reserva.reference.update({
        'estadoPago': montoPagar >= saldoPendiente ? 'Pagado' : 'Señal',
        'montoSenia': nuevaSenia,
        'montoRestante': montoTotal - nuevaSenia,
      });

      _mostrarSnackbar(
        '✅ Pago de ${_formatearMiles(montoPagar)} registrado',
        Colors.green,
      );
    }
  }

  void _editarReserva(DocumentSnapshot reserva) {
    _nombreController.text = reserva['nombre'];
    _telefonoController.text = reserva['telefono'];
    _horaSeleccionada = reserva['hora'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Reserva'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nombreController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _telefonoController,
              decoration: const InputDecoration(labelText: 'Teléfono'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _horaSeleccionada,
              items: _horarios
                  .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                  .toList(),
              onChanged: (v) => setState(() => _horaSeleccionada = v!),
              decoration: const InputDecoration(labelText: 'Hora'),
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
              await reserva.reference.update({
                'nombre': _nombreController.text,
                'telefono': _telefonoController.text,
                'hora': _horaSeleccionada,
              });
              Navigator.pop(context);
              _mostrarSnackbar('✅ Reserva actualizada', Colors.green);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _eliminarReserva(DocumentSnapshot reserva) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Reserva'),
        content: Text('¿Eliminar reserva de ${reserva['nombre']}?'),
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
      await reserva.reference.delete();
      _mostrarSnackbar('🗑️ Reserva eliminada', Colors.grey);
    }
  }

  void _mostrarResumenMensual() {
    final inicioMes = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final finMes = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);

    showDialog(
      context: context,
      builder: (context) => FutureBuilder(
        future: FirebaseFirestore.instance
            .collection('reservas')
            .where('fecha', isGreaterThanOrEqualTo: inicioMes)
            .where('fecha', isLessThanOrEqualTo: finMes)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final reservas = snapshot.data!.docs;
          double total = 0;
          for (var r in reservas) {
            if (r['estadoPago'] == 'Pagado') {
              total += (r['montoTotal'] as num).toDouble();
            } else if (r['estadoPago'] == 'Señal') {
              total += (r['montoSenia'] as num).toDouble();
            }
          }

          return AlertDialog(
            title: Text('Resumen ${_formatearFechaLarga(inicioMes)}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _infoRow(
                  Icons.calendar_today,
                  'Total reservas',
                  '${reservas.length}',
                ),
                const Divider(),
                _infoRow(
                  Icons.attach_money,
                  'Total recaudado',
                  _formatearMiles(total),
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
}
