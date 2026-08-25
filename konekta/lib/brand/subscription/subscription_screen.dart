import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../data/models/subscription.dart' as model;
import '../../subscription/dummy_qris_checkout_screen.dart';
import '../../subscription/subscription_cubit.dart';
import '../../subscription/subscription_widgets.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _mutating = false;
  int? _busyPlanId;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      context.read<SubscriptionCubit>().load();
    }
  }

  Future<void> _choosePlan(model.SubscriptionPlan plan) async {
    if (_mutating) return;
    final cubit = context.read<SubscriptionCubit>();
    final current = cubit.state.current;
    if (current != null && current.planId == plan.id && current.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You are already on the ${plan.name} plan')),
      );
      return;
    }

    final isPaidPlan = (plan.price ?? 0) > 0;
    if (isPaidPlan) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DummyQrisCheckoutScreen(plan: plan)),
      );
      return;
    }

    setState(() {
      _mutating = true;
      _busyPlanId = plan.id;
    });
    try {
      final updated = await cubit.subscribe(plan.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You are now on the ${updated.planName} plan')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Checkout failed: ${e.message}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Checkout failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _mutating = false;
          _busyPlanId = null;
        });
      }
    }
  }

  Future<void> _cancel() async {
    final cubit = context.read<SubscriptionCubit>();
    final current = cubit.state.current;
    if (current == null || !current.isActive) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel subscription?'),
        content: const Text('You will lose premium features when your current period ends.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Keep plan')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel', style: TextStyle(color: KonektaColors.danger)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _mutating = true);
    try {
      await cubit.cancelPlan();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subscription cancelled')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cancel failed: ${e.message}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cancel failed: $e')));
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SubscriptionCubit, SubscriptionState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: KonektaColors.bg,
          appBar: AppBar(
            backgroundColor: KonektaColors.surface,
            elevation: 1,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: KonektaColors.textPrimary, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text('Subscription Plans',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: KonektaColors.textPrimary)),
            actions: [
              IconButton(
                onPressed: state.loading ? null : () => context.read<SubscriptionCubit>().load(),
                icon: const Icon(Icons.refresh_rounded, color: KonektaColors.textPrimary),
              ),
            ],
          ),
          body: _buildBody(state),
        );
      },
    );
  }

  Widget _buildBody(SubscriptionState state) {
    if (state.loading && state.plans.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.plans.isEmpty) {
      return SubscriptionErrorState(message: state.error!, onRetry: () => context.read<SubscriptionCubit>().load());
    }
    return RefreshIndicator(
      onRefresh: () => context.read<SubscriptionCubit>().load(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          CurrentPlanCard(current: state.current, onCancel: _cancel, mutating: _mutating),
          const SizedBox(height: 18),
          const Text('Choose a plan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: KonektaColors.textDark)),
          const SizedBox(height: 4),
          const Text('Upgrade your account to unlock premium features.',
              style: TextStyle(fontSize: 12, color: KonektaColors.textSecondary)),
          const SizedBox(height: 14),
          if (state.plans.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: const [
                  Icon(Icons.workspace_premium_outlined, size: 56, color: KonektaColors.textMuted),
                  SizedBox(height: 8),
                  Text('No plans available right now',
                      style: TextStyle(color: KonektaColors.textMuted, fontSize: 13)),
                ],
              ),
            )
          else
            ...state.plans.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PlanCard(
                    plan: p,
                    isCurrent: state.current?.planId == p.id && (state.current?.isActive ?? false),
                    busy: _busyPlanId == p.id,
                    disabled: _mutating,
                    onChoose: () => _choosePlan(p),
                  ),
                )),
        ],
      ),
    );
  }
}