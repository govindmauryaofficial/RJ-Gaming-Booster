import 'package:flutter/material.dart';

const _red = Color(0xFFFF334F);
const _bg = Color(0xFF090A0F);
const _panel = Color(0xFF171922);
const _amber = Color(0xFFFFC857);

class AccessPlansPage extends StatelessWidget {
  const AccessPlansPage({super.key});

  // UI preview only. Never use a client-side username/flag as real authorization.
  // Production access must be verified by a trusted backend using authenticated user IDs.
  static const developerAllowlist = <String>{'govindmauryaofficial'};

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    appBar: AppBar(
      backgroundColor: _bg,
      title: const Text('RJ ACCESS & PLANS'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: const Color(0xFF302817),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: _amber.withOpacity(.55)),
          ),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.hourglass_top_rounded, color: _amber, size: 25),
            SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('PAYMENTS COMING SOON', style: TextStyle(color: _amber, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
              SizedBox(height: 7),
              Text('Payment setup is under review. Monthly and yearly plans are visible, but payment collection and premium activation are temporarily unavailable.', style: TextStyle(color: Colors.white70, height: 1.45, fontSize: 12)),
              SizedBox(height: 7),
              Text('Status: WAITING FOR PAYMENT GATEWAY APPROVAL', style: TextStyle(color: _amber, fontSize: 10, fontWeight: FontWeight.bold)),
            ])),
          ]),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: _red.withOpacity(.4))),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('DEVELOPER ACCESS', style: TextStyle(color: _red, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
            SizedBox(height: 8),
            Text('Owner account: govindmauryaofficial', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text('Developer plan: FREE • Intended for the verified owner account only', style: TextStyle(color: Colors.white70)),
          ]),
        ),
        const SizedBox(height: 18),
        const Text('USER SUBSCRIPTIONS', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        const SizedBox(height: 10),
        const _PlanCard(title: 'Monthly', price: '₹100', period: 'per month', description: 'Access for 30 days'),
        const SizedBox(height: 10),
        const _PlanCard(title: 'Yearly', price: '₹1,600', period: 'per year', description: 'Access for 12 months'),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(16)),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ADMIN PANEL • PREVIEW', style: TextStyle(color: _red, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
            SizedBox(height: 8),
            Text('• Review users and subscription status\n• Grant or revoke developer access\n• Manage monthly and yearly plans\n• View payment records', style: TextStyle(height: 1.7, color: Colors.white70)),
          ]),
        ),
        const SizedBox(height: 14),
        const Text('Payment options such as UPI, Google Pay and PhonePe will be added after gateway approval and integration. No payment is being collected on this screen. Owner access and admin controls are still a preview and must be secured by a backend before release.', style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5)),
      ],
    ),
  );
}

class _PlanCard extends StatelessWidget {
  final String title, price, period, description;
  const _PlanCard({required this.title, required this.price, required this.period, required this.description});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(16)),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        Text(description, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ])),
      Text(price, style: const TextStyle(color: _red, fontSize: 22, fontWeight: FontWeight.w900)),
      const SizedBox(width: 5),
      Text(period, style: const TextStyle(color: Colors.white54, fontSize: 10)),
    ]),
  );
}
