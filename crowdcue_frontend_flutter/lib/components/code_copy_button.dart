import 'package:flutter/material.dart'; // Import Material for ElevatedButton
import 'package:flutter/services.dart'; // Import for Clipboard

class CodeCopyButton extends StatefulWidget {
  final String code;

  const CodeCopyButton({super.key, required this.code});

  @override
  State<StatefulWidget> createState() => _CodeCopyButtonState(); // No parameters here
}

class _CodeCopyButtonState extends State<CodeCopyButton> {
  // No constructor needed for passing 'code'

  bool _isCopied = false;

  void _copyCode() async {
    await Clipboard.setData(
      ClipboardData(text: widget.code),
    ); // Access code via widget.code
    setState(() {
      _isCopied = true;
    });

    // Optional: Reset the "Copied!" message after a delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        // Check if the widget is still in the tree
        setState(() {
          _isCopied = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: _copyCode,
      child: RichText(
        text: TextSpan(
          text: _isCopied ? "Copied!" : "Copy Code: ",
          style: Theme.of(context).textTheme.bodyLarge,
          children: _isCopied
              ? []
              : [
                  TextSpan(
                    text: widget.code, // Access code via widget.code
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
        ),
      ),
      //  Text(
      //   _isCopied ? "Copied!" : "Copy Code: ${widget.code}",
      // ), // Access code via widget.code
    );
  }
}
