import 'package:flutter/material.dart';

import '../../models/PdfTemplate.dart';
import '../../services/PdfTemplateService.dart';
import '../../utils/app_colors.dart';
import 'PdfTemplateCard.dart';

/// Full-screen browse page for every available PDF template.
/// Route it however you like, e.g. context.go('/settings/pdf-templates')
/// or just push it directly as done from SettingsView.
class PdfTemplatesPage extends StatefulWidget {
  const PdfTemplatesPage({super.key});

  @override
  State<PdfTemplatesPage> createState() => _PdfTemplatesPageState();
}

class _PdfTemplatesPageState extends State<PdfTemplatesPage> {
  late String _selectedId = PdfTemplateService.selected.id;
  bool _applying = false;

  Future<void> _apply(PdfTemplate template) async {
    setState(() {
      _selectedId = template.id;
      _applying = true;
    });
    await PdfTemplateService.select(template);
    if (!mounted) return;
    setState(() => _applying = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${template.name} template applied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        title: Text('All templates',
            style: TextStyle(
                color: AppColors.textPrimary(context),
                fontWeight: FontWeight.w700)),
        iconTheme: IconThemeData(color: AppColors.textPrimary(context)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select a layout for all your invoices',
                  style: TextStyle(
                      color: AppColors.textSecondary(context), fontSize: 13)),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  itemCount: PdfTemplateCatalog.all.length,
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.82,
                  ),
                  itemBuilder: (_, i) {
                    final t = PdfTemplateCatalog.all[i];
                    return PdfTemplateCard(
                      template: t,
                      isSelected: t.id == _selectedId,
                      onTap: _applying ? () {} : () => _apply(t),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}