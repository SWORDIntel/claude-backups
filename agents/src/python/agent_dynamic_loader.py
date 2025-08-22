"""Dynamic Agent Class Loader - Handles naming inconsistencies"""
import logging
from typing import Dict, Any

logger = logging.getLogger(__name__)

def get_agent_executor_class(agent_name: str):
    """Get the correct PythonExecutor class name for an agent"""
    class_mapping = {
        "apidesigner": "APIDESIGNERPythonExecutor",
        "architect": "ARCHITECTPythonExecutor",
        "bastion": "BASTIONPythonExecutor",
        "constructor": "CONSTRUCTORPythonExecutor",
        "cryptoexpert": "CRYPTOEXPERTPythonExecutor",
        "cso": "CSOPythonExecutor",
        "database": "DatabasePythonExecutor",
        "datascience": "DATASCIENCEPythonExecutor",
        "debugger": "DEBUGGERPythonExecutor",
        "deployer": "DEPLOYERPythonExecutor",
        "director": "DirectorPythonExecutor",
        "docgen": "DOCGENPythonExecutor",
        "infrastructure": "INFRASTRUCTUREPythonExecutor",
        "linter": "LINTERPythonExecutor",
        "mlops": "MLOPSPythonExecutor",
        "monitor": "MONITORPythonExecutor",
        "optimizer": "OPTIMIZERPythonExecutor",
        "oversight": "OVERSIGHTPythonExecutor",
        "packager": "PACKAGERPythonExecutor",
        "patcher": "PATCHERPythonExecutor",
        "projectorchestrator": "PROJECTORCHESTRATORPythonExecutor",
        "pygui": "PYGUIPythonExecutor",
        "quantumguard": "QUANTUMGUARDPythonExecutor",
        "redteamorchestrator": "REDTEAMORCHESTRATORPythonExecutor",
        "security": "SecurityPythonExecutor",
        "securityauditor": "SECURITYAUDITORPythonExecutor",
        "securitychaosagent": "SecurityChaosAgentPythonExecutor",
        "testbed": "TESTBEDPythonExecutor",
        "web": "WEBPythonExecutor",
    }
    return class_mapping.get(agent_name)

async def invoke_agent_dynamically(agent_name: str, action: str, context: Dict[str, Any]) -> Dict[str, Any]:
    """Dynamically invoke an agent with correct class name"""
    class_name = get_agent_executor_class(agent_name)
    if not class_name:
        return {
            'status': 'error',
            'message': f'Unknown agent: {agent_name}',
            'agent': agent_name
        }

    try:
        # Dynamic import and instantiation
        module_name = f'{agent_name}_impl'
        module = __import__(module_name, fromlist=[class_name])
        executor_class = getattr(module, class_name)
        executor = executor_class()

        # Execute the action using the correct method name
        result = await executor.execute_command(action, context)
        return result

    except Exception as e:
        logger.error(f'Error invoking {agent_name}: {e}')
        return {
            'status': 'error',
            'message': str(e),
            'agent': agent_name,
            'action': action
        }