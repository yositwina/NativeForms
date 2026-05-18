NativeFormsSetupController.ConnectionStatus status =
    NativeFormsSetupController.getConnectionStatus(null, true);
System.debug('BOOTSTRAP_V2_STATUS=' + JSON.serialize(status));
